import { describe, it, expect, beforeEach, jest } from '@jest/globals';

jest.mock('@nestjs/typeorm', () => ({
  InjectRepository: () => () => {},
  getRepositoryToken: (entity: any) => entity,
}));

jest.mock('@nestjs/config', () => ({
  ConfigService: jest.fn().mockImplementation(() => ({
    get: jest.fn(),
  })),
}));

import { DashboardService } from './dashboard.service';
import { AccessLog } from '../../../access/domain/entities/access-log.entity';
import { CapacityStatus } from '../../domain/enums/capacity-status.enum';
import { Repository } from 'typeorm';
import { ConfigService } from '@nestjs/config';

describe('DashboardService', () => {
  let service: DashboardService;
  let accessLogRepo: jest.Mocked<Repository<AccessLog>>;
  let configService: jest.Mocked<ConfigService>;

  beforeEach(() => {
    accessLogRepo = {
      query: jest.fn(),
    } as unknown as jest.Mocked<Repository<AccessLog>>;

    configService = {
      get: jest.fn(),
    } as unknown as jest.Mocked<ConfigService>;

    service = new DashboardService(accessLogRepo, configService);
  });

  describe('getCurrentOccupancy', () => {
    it('tính đúng số người hiện tại, tỷ lệ lấp đầy và trạng thái NORMAL (< 70%)', async () => {
      accessLogRepo.query.mockResolvedValueOnce([{ count: 142 }]);
      configService.get.mockReturnValue(500);

      const result = await service.getCurrentOccupancy();

      expect(result.currentOccupants).toBe(142);
      expect(result.maxCapacity).toBe(500);
      expect(result.occupancyRate).toBe(28.4);
      expect(result.status).toBe(CapacityStatus.NORMAL);
      expect(result.updatedAt).toBeInstanceOf(Date);
    });

    it('tính đúng trạng thái WARNING (70% - 89%)', async () => {
      accessLogRepo.query.mockResolvedValueOnce([{ count: 375 }]);
      configService.get.mockReturnValue(500);

      const result = await service.getCurrentOccupancy();

      expect(result.currentOccupants).toBe(375);
      expect(result.maxCapacity).toBe(500);
      expect(result.occupancyRate).toBe(75);
      expect(result.status).toBe(CapacityStatus.WARNING);
    });

    it('tính đúng trạng thái FULL (>= 90%)', async () => {
      accessLogRepo.query.mockResolvedValueOnce([{ count: 480 }]);
      configService.get.mockReturnValue(500);

      const result = await service.getCurrentOccupancy();

      expect(result.currentOccupants).toBe(480);
      expect(result.maxCapacity).toBe(500);
      expect(result.occupancyRate).toBe(96);
      expect(result.status).toBe(CapacityStatus.FULL);
    });

    it('fallback maxCapacity = 500 khi config không hợp lệ', async () => {
      accessLogRepo.query.mockResolvedValueOnce([{ count: 0 }]);
      configService.get.mockReturnValue(0 as any);

      const result = await service.getCurrentOccupancy();

      expect(result.maxCapacity).toBe(500);
      expect(result.currentOccupants).toBe(0);
      expect(result.occupancyRate).toBe(0);
      expect(result.status).toBe(CapacityStatus.NORMAL);
    });
  });

  describe('getCheckInOutStatistic', () => {
    it('tính đúng check-in, check-out, peak và lowest theo từng interval', async () => {
      const startDate = new Date('2026-10-26T08:00:00.000Z');
      const endDate = new Date('2026-10-26T10:00:00.000Z');
      const intervalMin = 60;

      accessLogRepo.query
        .mockResolvedValueOnce([{ count: 2 }])
        .mockResolvedValueOnce([
          {
            startDate: '2026-10-26T08:00:00.000Z',
            checkInCount: 1,
            checkOutCount: 1,
          },
          {
            startDate: '2026-10-26T09:00:00.000Z',
            checkInCount: 2,
            checkOutCount: 0,
          },
        ]);

      const result = await service.getCheckInOutStatistic({
        startDate,
        endDate,
        intervalMin,
      });

      expect(result).toHaveLength(2);

      expect(result[0]).toEqual({
        startDate: new Date('2026-10-26T08:00:00.000Z'),
        intervalMin: 60,
        checkInCount: 1,
        checkOutCount: 1,
        peakPeopleCount: 3,
        lowestPeopleCount: 1,
      });

      expect(result[1]).toEqual({
        startDate: new Date('2026-10-26T09:00:00.000Z'),
        intervalMin: 60,
        checkInCount: 2,
        checkOutCount: 0,
        peakPeopleCount: 4,
        lowestPeopleCount: 2,
      });
    });

    it('trả về mảng rỗng khi khoảng thời gian không hợp lệ', async () => {
      const result = await service.getCheckInOutStatistic({
        startDate: new Date('2026-10-26T10:00:00.000Z'),
        endDate: new Date('2026-10-26T08:00:00.000Z'),
        intervalMin: 60,
      });

      expect(result).toEqual([]);
    });

    it('giới hạn endDate về hiện tại và không gọi query nếu startDate ở tương lai', async () => {
      const futureStart = new Date(Date.now() + 1000 * 60 * 60 * 24);
      const futureEnd = new Date(futureStart.getTime() + 1000 * 60 * 60);

      const result = await service.getCheckInOutStatistic({
        startDate: futureStart,
        endDate: futureEnd,
        intervalMin: 60,
      });

      expect(result).toEqual([]);
      expect(accessLogRepo.query).not.toHaveBeenCalled();
    });

    it('loại bỏ các mốc thời gian vượt quá thời điểm hiện tại', async () => {
      const pastStart = new Date(Date.now() - 1000 * 60 * 90); // 90 mins ago
      const futureEnd = new Date(Date.now() + 1000 * 60 * 60); // 60 mins ahead

      const pastBucket = new Date(Date.now() - 1000 * 60 * 60).toISOString();
      const futureBucket = new Date(Date.now() + 1000 * 60 * 30).toISOString();

      accessLogRepo.query
        .mockResolvedValueOnce([{ count: 5 }])
        .mockResolvedValueOnce([
          {
            startDate: pastBucket,
            checkInCount: 3,
            checkOutCount: 1,
          },
          {
            startDate: futureBucket,
            checkInCount: 0,
            checkOutCount: 0,
          },
        ]);

      const result = await service.getCheckInOutStatistic({
        startDate: pastStart,
        endDate: futureEnd,
        intervalMin: 60,
      });

      expect(result).toHaveLength(1);
      expect(result[0].startDate).toEqual(new Date(pastBucket));
      expect(result.some((r) => r.startDate.getTime() > Date.now())).toBe(false);
    });
  });
});
