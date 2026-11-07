import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { createHash } from 'crypto';
import { DataSource, EntityManager } from 'typeorm';
import { AccessLog } from '../../../access/domain/entities/access-log.entity';
import { AccessAction } from '../../../access/domain/enums/access-action.enum';
import { AccessMethod } from '../../../access/domain/enums/access-method.enum';
import { AccessResult } from '../../../access/domain/enums/access-result.enum';
import { Device } from '../../../device/domain/entities/device.entity';
import { Gate } from '../../../device/domain/entities/gate.entity';
import { DeviceStatus } from '../../../device/domain/enums/device-status.enum';
import { GateStatus } from '../../../device/domain/enums/gate-status.enum';
import { QrToken } from '../../../qr/domain/entities/qr-token.entity';
import { QrTokenStatus } from '../../../qr/domain/enums/qr-token-status.enum';
import { Role } from '../../../user/domain/enums/role.enum';
import { UserStatus } from '../../../user/domain/enums/user-statis.enum';
import { User } from '../../../user/domain/entities/user.entity';
import { CheckInOutDto } from '../../infra/dto/checkin-out.dto';
import { ManualCheckInOutDto } from '../../infra/dto/manual-checkin-out.dto';
import { AccessStateService, ReaderAccessState } from './access-state.service';
import { IdentifyFaceService } from '../../../biommetric/face-biometric/application/services/identify-face.service';
import {
  INTERNAL_EVENT_BUS,
  InternalEventBus,
} from '../../../infra/event/application/internal-event-bus.interface';
import { ReaderAccessEvent } from '../../domain/events/reader-access.event';
import { ScheduleService } from '../../../library/application/services/schedule.service';

@Injectable()
export class CheckInOutService {
  constructor(
    private readonly dataSource: DataSource,
    private readonly accessStateService: AccessStateService,
    private readonly identifyFaceService: IdentifyFaceService,
    private readonly scheduleService: ScheduleService,
    @Inject(INTERNAL_EVENT_BUS)
    private readonly eventService: InternalEventBus,
  ) {}

  private async ensureLibraryOpenForCheckIn(now: Date): Promise<void> {
    const status = await this.scheduleService.getStatusAt(now);
    // Nếu đã cấu hình lịch mà thư viện đang đóng (CLOSED_ALL_DAY hoặc OUTSIDE_HOURS) thì chặn check-in
    if (!status.isOpen && status.reason !== 'NO_SCHEDULE') {
      const msg =
        status.reason === 'CLOSED_ALL_DAY'
          ? 'Thư viện hôm nay đóng cửa theo lịch, không thể check-in.'
          : 'Thư viện hiện đang ngoài giờ mở cửa, không thể check-in.';
      throw new ForbiddenException(msg);
    }
  }

  async checkInOut(staffId: string, dto: CheckInOutDto) {
    const now = new Date();
    const tokenHash = createHash('sha256').update(dto.token).digest('hex');

    return this.dataSource.transaction(async (manager) => {
      const userRepository = manager.getRepository(User);
      const qrTokenRepository = manager.getRepository(QrToken);
      const deviceRepository = manager.getRepository(Device);
      const gateRepository = manager.getRepository(Gate);
      const accessLogRepository = manager.getRepository(AccessLog);

      const staff = await userRepository.findOne({
        where: {
          id: staffId,
          role: Role.STAFF,
          status: UserStatus.ACTIVE,
        },
      });

      if (!staff) {
        throw new ForbiddenException(
          'Tài khoản nhân viên không hợp lệ hoặc đã bị vô hiệu hóa.',
        );
      }

      const qrToken = await qrTokenRepository
        .createQueryBuilder('qr')
        .innerJoinAndSelect('qr.reader', 'reader')
        .where('qr.tokenHash = :tokenHash', { tokenHash })
        .setLock('pessimistic_write')
        .getOne();

      if (!qrToken) {
        throw new NotFoundException(
          'QR token không tồn tại hoặc không hợp lệ.',
        );
      }

      if (
        qrToken.status !== QrTokenStatus.ACTIVE ||
        qrToken.usedAt ||
        qrToken.revokedAt ||
        qrToken.expiresAt <= now
      ) {
        throw new BadRequestException(
          'QR token đã hết hạn, đã bị thu hồi hoặc đã được sử dụng.',
        );
      }

      const readerId = qrToken.reader?.id;

      if (!readerId) {
        throw new BadRequestException('QR token không liên kết với Reader.');
      }

      const reader = await userRepository
        .createQueryBuilder('reader')
        .where('reader.id = :readerId', { readerId })
        .andWhere('reader.role = :role', { role: Role.READER })
        .setLock('pessimistic_write')
        .getOne();

      if (!reader) {
        throw new NotFoundException('Không tìm thấy Reader.');
      }

      if (reader.status !== UserStatus.ACTIVE) {
        throw new ForbiddenException('Tài khoản Reader đã bị vô hiệu hóa.');
      }

      const device = await deviceRepository
        .createQueryBuilder('device')
        .where('device.staffId = :staffId', { staffId })
        .andWhere('device.status = :status', {
          status: DeviceStatus.ACTIVE,
        })
        .andWhere('device.revokedAt IS NULL')
        .orderBy('device.assignedAt', 'DESC')
        .addOrderBy('device.createdAt', 'DESC')
        .getOne();

      if (!device) {
        throw new ForbiddenException(
          'Nhân viên chưa đăng nhập trên thiết bị đã đăng ký. Hãy đăng nhập lại hoặc liên hệ quản trị viên để gỡ thiết bị cũ.',
        );
      }

      if (!device.gateId) {
        throw new ForbiddenException(
          'Thiết bị đã đăng ký nhưng chưa được gán cổng. Yêu cầu quản trị viên gán cổng cho nhân viên trong phần Quản lý cổng.',
        );
      }

      const gate = await gateRepository.findOne({
        where: {
          id: device.gateId,
          status: GateStatus.ACTIVE,
        },
      });

      if (!gate) {
        throw new ForbiddenException(
          'Cổng được gán cho thiết bị không hoạt động.',
        );
      }

      const currentState = await this.accessStateService.getCurrentState(
        manager,
        reader.id,
      );

      const accessAction =
        currentState === ReaderAccessState.OUT
          ? AccessAction.CHECK_IN
          : AccessAction.CHECK_OUT;

      if (accessAction === AccessAction.CHECK_IN) {
        await this.ensureLibraryOpenForCheckIn(now);
      }

      const newState =
        accessAction === AccessAction.CHECK_IN
          ? ReaderAccessState.IN
          : ReaderAccessState.OUT;

      const accessLog = accessLogRepository.create({
        readerId: reader.id,
        staffId: staff.id,
        deviceId: device.id,
        gateId: gate.id,
        action: accessAction,
        method: AccessMethod.QR,
        result: AccessResult.SUCCESS,
        occurredAt: now,
      });

      const savedLog = await accessLogRepository.save(accessLog);

      qrToken.status = QrTokenStatus.USED;
      qrToken.usedAt = now;
      await qrTokenRepository.save(qrToken);

      await this.eventService.publish(
        new ReaderAccessEvent(
          accessAction,
          reader.id,
          device.id,
          savedLog.id,
          now,
          reader.fullName,
          gate.id,
          gate.name,
          AccessMethod.QR,
        ),
      );

      return {
        success: true,
        message:
          accessAction === AccessAction.CHECK_IN
            ? 'Check-in thành công.'
            : 'Check-out thành công.',
        data: {
          accessLogId: savedLog.id,
          readerId: reader.id,
          staffId: staff.id,
          deviceId: device.id,
          gateId: gate.id,
          action: savedLog.action,
          method: savedLog.method,
          result: savedLog.result,
          state: newState,
          occurredAt: savedLog.occurredAt,
        },
      };
    });
  }

  async checkInOutByFace(staffId: string, imageBuffer: Buffer) {
    const identity = await this.identifyFaceService.execute(imageBuffer);
    const now = new Date();

    return this.dataSource.transaction(async (manager) => {
      const userRepository = manager.getRepository(User);
      const deviceRepository = manager.getRepository(Device);
      const gateRepository = manager.getRepository(Gate);
      const accessLogRepository = manager.getRepository(AccessLog);

      const staff = await userRepository.findOne({
        where: {
          id: staffId,
          role: Role.STAFF,
          status: UserStatus.ACTIVE,
        },
      });

      if (!staff) {
        throw new ForbiddenException(
          'Tài khoản nhân viên không hợp lệ hoặc đã bị vô hiệu hóa.',
        );
      }

      const reader = await userRepository
        .createQueryBuilder('reader')
        .where('reader.id = :readerId', {
          readerId: identity.readerId,
        })
        .andWhere('reader.role = :role', {
          role: Role.READER,
        })
        .setLock('pessimistic_write')
        .getOne();

      if (!reader) {
        throw new NotFoundException('Không tìm thấy Reader.');
      }

      if (reader.status !== UserStatus.ACTIVE) {
        throw new ForbiddenException('Tài khoản Reader đã bị vô hiệu hóa.');
      }

      const device = await deviceRepository
        .createQueryBuilder('device')
        .where('device.staffId = :staffId', { staffId })
        .andWhere('device.status = :status', {
          status: DeviceStatus.ACTIVE,
        })
        .andWhere('device.revokedAt IS NULL')
        .orderBy('device.assignedAt', 'DESC')
        .addOrderBy('device.createdAt', 'DESC')
        .getOne();

      if (!device) {
        throw new ForbiddenException(
          'Nhân viên chưa đăng nhập trên thiết bị đã đăng ký. Hãy đăng nhập lại hoặc liên hệ quản trị viên để gỡ thiết bị cũ.',
        );
      }

      if (!device.gateId) {
        throw new ForbiddenException(
          'Thiết bị đã đăng ký nhưng chưa được gán cổng. Yêu cầu quản trị viên gán cổng cho nhân viên trong phần Quản lý cổng.',
        );
      }

      const gate = await gateRepository.findOne({
        where: {
          id: device.gateId,
          status: GateStatus.ACTIVE,
        },
      });

      if (!gate) {
        throw new ForbiddenException(
          'Cổng được gán cho thiết bị không hoạt động.',
        );
      }

      const currentState = await this.accessStateService.getCurrentState(
        manager,
        reader.id,
      );

      const accessAction =
        currentState === ReaderAccessState.OUT
          ? AccessAction.CHECK_IN
          : AccessAction.CHECK_OUT;

      if (accessAction === AccessAction.CHECK_IN) {
        await this.ensureLibraryOpenForCheckIn(now);
      }

      const newState =
        accessAction === AccessAction.CHECK_IN
          ? ReaderAccessState.IN
          : ReaderAccessState.OUT;

      const accessLog = accessLogRepository.create({
        readerId: reader.id,
        staffId: staff.id,
        deviceId: device.id,
        gateId: gate.id,
        action: accessAction,
        method: AccessMethod.FACE,
        result: AccessResult.SUCCESS,
        occurredAt: now,
      });

      const savedLog = await accessLogRepository.save(accessLog);

      await this.eventService.publish(
        new ReaderAccessEvent(
          accessAction,
          reader.id,
          device.id,
          savedLog.id,
          now,
          reader.fullName,
          gate.id,
          gate.name,
          AccessMethod.FACE,
        ),
      );

      return {
        success: true,
        message:
          accessAction === AccessAction.CHECK_IN
            ? 'Face check-in thành công.'
            : 'Face check-out thành công.',
        data: {
          accessLogId: savedLog.id,
          readerId: reader.id,
          staffId: staff.id,
          deviceId: device.id,
          gateId: gate.id,
          action: savedLog.action,
          method: savedLog.method,
          result: savedLog.result,
          state: newState,
          occurredAt: savedLog.occurredAt,
          similarity: identity.similarity,
        },
      };
    });
  }

  async getReaderAccessState(readerId: string) {
    return this.dataSource.transaction(async (manager) => {
      const userRepository = manager.getRepository(User);
      const accessLogRepository = manager.getRepository(AccessLog);

      const reader = await userRepository.findOne({
        where: { id: readerId, role: Role.READER },
      });

      if (!reader) {
        throw new NotFoundException('Không tìm thấy bạn đọc.');
      }

      const currentState = await this.accessStateService.getCurrentState(
        manager,
        reader.id,
      );

      const latestLog = await accessLogRepository.findOne({
        where: { readerId: reader.id, result: AccessResult.SUCCESS },
        order: { occurredAt: 'DESC', createdAt: 'DESC', id: 'DESC' },
      });

      return {
        readerId: reader.id,
        fullName: reader.fullName,
        email: reader.email,
        status: reader.status,
        state: currentState,
        suggestedAction:
          currentState === ReaderAccessState.OUT
            ? AccessAction.CHECK_IN
            : AccessAction.CHECK_OUT,
        latestLog: latestLog
          ? {
              id: latestLog.id,
              action: latestLog.action,
              method: latestLog.method,
              occurredAt: latestLog.occurredAt,
              reason: latestLog.reason,
            }
          : null,
      };
    });
  }

  /**
   * Tìm thiết bị/cổng hợp lệ cho thao tác Manual Access hoặc Auto Check-out.
   * Giữ nguyên 100% schema bảng access_logs (device_id NOT NULL).
   */
  async resolveDeviceAndGateForActor(
    manager: EntityManager,
    actorId: string,
    now: Date,
  ): Promise<{ device: Device; gate: Gate }> {
    const deviceRepository = manager.getRepository(Device);
    const gateRepository = manager.getRepository(Gate);

    // 1. Ưu tiên thiết bị đang active của chính nhân viên/admin đó
    let device = await deviceRepository
      .createQueryBuilder('device')
      .where('device.staffId = :staffId', { staffId: actorId })
      .andWhere('device.status = :status', { status: DeviceStatus.ACTIVE })
      .andWhere('device.revokedAt IS NULL')
      .orderBy('device.assignedAt', 'DESC')
      .addOrderBy('device.createdAt', 'DESC')
      .getOne();

    // 2. Nếu người duyệt (VD: Admin hoặc nhân viên quầy) chưa gán thiết bị, dùng thiết bị bất kỳ có sẵn
    if (!device) {
      device = await deviceRepository.findOne({
        where: { status: DeviceStatus.ACTIVE },
        relations: { gate: true },
        order: { createdAt: 'DESC' },
      });
    }
    if (!device) {
      device = await deviceRepository.findOne({
        where: {},
        relations: { gate: true },
        order: { createdAt: 'DESC' },
      });
    }

    // 3. Nếu hệ thống hoàn toàn chưa có cổng/thiết bị nào trong DB, tự tạo cổng & thiết bị Quầy Thủ Thư mặc định
    let gate = device?.gateId
      ? await gateRepository.findOne({ where: { id: device.gateId } })
      : null;

    if (!gate) {
      gate = await gateRepository.findOne({
        where: { code: 'MANUAL-DESK' },
      });
      if (!gate) {
        gate = await gateRepository.save(
          gateRepository.create({
            code: 'MANUAL-DESK',
            name: 'Quầy thủ thư (Duyệt thủ công)',
            location: 'Sảnh chính',
            status: GateStatus.ACTIVE,
          }),
        );
      }
    }

    if (!device) {
      device = await deviceRepository.save(
        deviceRepository.create({
          staffId: actorId,
          gateId: gate.id,
          deviceName: 'Quầy thủ thư (Manual Desk)',
          devicePlatform: 'WEB/ADMIN',
          status: DeviceStatus.ACTIVE,
          assignedById: actorId,
          assignedAt: now,
          activatedAt: now,
        }),
      );
    }

    return { device, gate };
  }

  async checkInOutManual(actorId: string, dto: ManualCheckInOutDto) {
    const now = new Date();
    const trimmedReason = dto.reason?.trim();
    if (!trimmedReason) {
      throw new BadRequestException(
        'Vui lòng nhập lý do duyệt ra/vào thủ công.',
      );
    }

    return this.dataSource.transaction(async (manager) => {
      const userRepository = manager.getRepository(User);
      const accessLogRepository = manager.getRepository(AccessLog);

      const actor = await userRepository.findOne({
        where: {
          id: actorId,
          status: UserStatus.ACTIVE,
        },
      });

      if (!actor || (actor.role !== Role.STAFF && actor.role !== Role.ADMIN)) {
        throw new ForbiddenException(
          'Tài khoản nhân viên/quản trị viên không hợp lệ hoặc đã bị vô hiệu hóa.',
        );
      }

      const reader = await userRepository
        .createQueryBuilder('reader')
        .where('reader.id = :readerId', { readerId: dto.readerId })
        .andWhere('reader.role = :role', { role: Role.READER })
        .setLock('pessimistic_write')
        .getOne();

      if (!reader) {
        throw new NotFoundException('Không tìm thấy bạn đọc.');
      }

      if (reader.status !== UserStatus.ACTIVE) {
        throw new ForbiddenException(
          'Tài khoản bạn đọc đã bị khóa hoặc vô hiệu hóa.',
        );
      }

      const currentState = await this.accessStateService.getCurrentState(
        manager,
        reader.id,
      );

      const expectedAction =
        currentState === ReaderAccessState.OUT
          ? AccessAction.CHECK_IN
          : AccessAction.CHECK_OUT;

      const accessAction = dto.action ?? expectedAction;

      if (
        accessAction !== AccessAction.CHECK_IN &&
        accessAction !== AccessAction.CHECK_OUT
      ) {
        throw new BadRequestException(
          'Hành động duyệt thủ công chỉ chấp nhận CHECK_IN hoặc CHECK_OUT.',
        );
      }

      if (
        accessAction === AccessAction.CHECK_IN &&
        currentState === ReaderAccessState.IN
      ) {
        throw new BadRequestException(
          'Bạn đọc này hiện đang ở TRONG thư viện, chỉ có thể thực hiện CHECK_OUT.',
        );
      }

      if (
        accessAction === AccessAction.CHECK_OUT &&
        currentState === ReaderAccessState.OUT
      ) {
        throw new BadRequestException(
          'Bạn đọc này hiện đang ở NGOÀI thư viện, chỉ có thể thực hiện CHECK_IN.',
        );
      }

      const { device, gate } = await this.resolveDeviceAndGateForActor(
        manager,
        actor.id,
        now,
      );

      const newState =
        accessAction === AccessAction.CHECK_IN
          ? ReaderAccessState.IN
          : ReaderAccessState.OUT;

      const accessLog = accessLogRepository.create({
        readerId: reader.id,
        staffId: actor.id,
        deviceId: device.id,
        gateId: gate.id,
        action: accessAction,
        method: AccessMethod.MANUAL,
        result: AccessResult.SUCCESS,
        reason: trimmedReason,
        occurredAt: now,
      });

      const savedLog = await accessLogRepository.save(accessLog);

      await this.eventService.publish(
        new ReaderAccessEvent(
          accessAction,
          reader.id,
          device.id,
          savedLog.id,
          now,
          reader.fullName,
          gate.id,
          gate.name,
          AccessMethod.MANUAL,
        ),
      );

      return {
        success: true,
        message:
          accessAction === AccessAction.CHECK_IN
            ? `Đã duyệt Check-in thủ công cho ${reader.fullName}.`
            : `Đã duyệt Check-out thủ công cho ${reader.fullName}.`,
        data: {
          accessLogId: savedLog.id,
          readerId: reader.id,
          readerName: reader.fullName,
          readerEmail: reader.email,
          staffId: actor.id,
          staffName: actor.fullName,
          deviceId: device.id,
          gateId: gate.id,
          gateName: gate.name,
          action: savedLog.action,
          method: savedLog.method,
          result: savedLog.result,
          reason: savedLog.reason,
          state: newState,
          occurredAt: savedLog.occurredAt,
        },
      };
    });
  }
}
