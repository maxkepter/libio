import { Injectable } from '@nestjs/common';
import { EventHandler } from '../../../../common/application/event/event-handler.interface';
import { ReaderAccessEvent } from '../../../checkin-out/domain/events/reader-access.event';
import { DashboardStreamService } from '../services/dashboard-stream.service';
import { BaseService } from '../../../../common/application/service/base.service';

@Injectable()
export class ReaderAccessHandler
  extends BaseService
  implements EventHandler<ReaderAccessEvent>
{
  constructor(private readonly dashboardStreamService: DashboardStreamService) {
    super(ReaderAccessHandler.name);
  }

  handle(data: ReaderAccessEvent): Promise<void> {
    this.logger.debug(`Handling ReaderAccessEvent: ${JSON.stringify(data)}`);

    const payload = JSON.stringify({
      action: data.action,
      readerId: data.readerId,
      deviceId: data.deviceId,
      accessLogId: data.accessLogId,
      occurredAt: data.occurredAt,
      readerName: data.readerName,
      gateId: data.gateId,
      gateName: data.gateName,
      method: data.method,
    });
    this.logger.debug(`ReaderAccess payload: ${payload}`);
    this.dashboardStreamService.publishReaderAccessEvent(
      new MessageEvent('reader.access', { data: payload }),
    );
    return Promise.resolve();
  }
}
