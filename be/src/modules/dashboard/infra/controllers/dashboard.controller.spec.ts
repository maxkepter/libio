import { describe, it, expect, beforeEach, jest } from '@jest/globals';

jest.mock('@nestjs/passport', () => ({
  AuthGuard: () => () => {},
}));

jest.mock('@nestjs/typeorm', () => ({
  InjectRepository: () => () => {},
  getRepositoryToken: (entity: any) => entity,
}));

jest.mock('@nestjs/config', () => ({
  ConfigService: jest.fn().mockImplementation(() => ({
    get: jest.fn(),
  })),
}));

jest.mock('../../../auth/infra/guard/jwt.guard', () => ({
  JwtGuard: jest.fn().mockImplementation(() => ({})),
}));

jest.mock('../../../auth/infra/guard/role.guard', () => ({
  RoleGuard: jest.fn().mockImplementation(() => ({})),
}));

import { DashboardController } from './dashboard.controller';
import { DashboardService } from '../../application/services/dashboard.service';
import { DashboardStreamService } from '../../application/services/dashboard-stream.service';
import { CapacityStatus } from '../../domain/enums/capacity-status.enum';
import {
  OccupancyDashboardRes,
  CheckInOutDashboardRes,
} from '../../dto/res.dto';

describe('DashboardController (infra)', () => {
  let controller: DashboardController;
  let service: jest.Mocked<DashboardService>;

  beforeEach(() => {
    service = {
      getCurrentOccupancy: jest.fn(),
      getCheckInOutStatistic: jest.fn(),
    } as unknown as jest.Mocked<DashboardService>;

    controller = new DashboardController(
      service,
      { getReaderAccessEvents: jest.fn() } as unknown as DashboardStreamService,
    );
  });

  describe('getOccupancy', () => {
    it('gọi service.getCurrentOccupancy và trả về kết quả', async () => {
      const mockRes: OccupancyDashboardRes = {
        currentOccupants: 120,
        maxCapacity: 500,
        occupancyRate: 24.0,
        status: CapacityStatus.NORMAL,
        updatedAt: new Date('2026-10-27T10:00:00.000Z'),
      };

      service.getCurrentOccupancy.mockResolvedValue(mockRes);

      const result = await controller.getOccupancy();

      expect(service.getCurrentOccupancy).toHaveBeenCalledTimes(1);
      expect(result).toEqual(mockRes);
    });
  });

  describe('getCheckInOutStatistic', () => {
    it('gọi service.getCheckInOutStatistic với đúng query dto', async () => {
      const mockQuery = {
        startDate: '2026-10-20T00:00:00.000Z',
        endDate: '2026-10-27T23:59:59.999Z',
        intervalMin: 60,
      };

      const mockStats: CheckInOutDashboardRes[] = [
        {
          startDate: new Date('2026-10-27T08:00:00.000Z'),
          intervalMin: 60,
          checkInCount: 10,
          checkOutCount: 2,
          peakPeopleCount: 15,
          lowestPeopleCount: 5,
        },
      ];

      service.getCheckInOutStatistic.mockResolvedValue(mockStats);

      const result = await controller.getCheckInOutStatistic(mockQuery);

      expect(service.getCheckInOutStatistic).toHaveBeenCalledWith(mockQuery);
      expect(result).toEqual(mockStats);
    });
  });
});
