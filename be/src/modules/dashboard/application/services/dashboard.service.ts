import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CheckInOutStatisticUsecase } from '../usecases/check-in-out-statistic.usecase';
import { OccupancyStatisticUsecase } from '../usecases/occupancy-statistic.usecase';
import { CheckInOutDashboardReq } from '../../dto/req.dto';
import {
  CheckInOutDashboardRes,
  OccupancyDashboardRes,
} from '../../dto/res.dto';
import { AccessLog } from '../../../access/domain/entities/access-log.entity';
import { AccessAction } from '../../../access/domain/enums/access-action.enum';
import { AccessResult } from '../../../access/domain/enums/access-result.enum';
import { getCapacityStatus } from '../../domain/enums/capacity-status.enum';

interface RawBucketStats {
  startDate: Date | string;
  checkInCount: number | string;
  checkOutCount: number | string;
}

@Injectable()
export class DashboardService
  implements CheckInOutStatisticUsecase, OccupancyStatisticUsecase
{
  constructor(
    @InjectRepository(AccessLog)
    private readonly accessLogRepo: Repository<AccessLog>,
    private readonly configService: ConfigService,
  ) {}

  async getCurrentOccupancy(): Promise<OccupancyDashboardRes> {
    const rawResult = await this.accessLogRepo.query<
      Array<{ count?: number | string }>
    >(
      `
      SELECT COUNT(*)::int AS count
      FROM (
        SELECT action,
               ROW_NUMBER() OVER (
                 PARTITION BY reader_id
                 ORDER BY occurred_at DESC, created_at DESC, id DESC
               ) AS rn
        FROM access_logs
        WHERE result = $1
      ) t
      WHERE t.rn = 1 AND t.action = $2
      `,
      [AccessResult.SUCCESS, AccessAction.CHECK_IN],
    );

    const currentOccupants = Number(rawResult[0]?.count ?? 0);
    const configuredCapacity = this.configService.get<number>(
      'LIBRARY_MAX_CAPACITY',
      500,
    );
    const maxCapacity =
      Number(configuredCapacity) > 0 ? Number(configuredCapacity) : 500;

    const rawRate = (currentOccupants / maxCapacity) * 100;
    const occupancyRate = Number(rawRate.toFixed(1));
    const status = getCapacityStatus(occupancyRate);

    return {
      currentOccupants,
      maxCapacity,
      occupancyRate,
      status,
      updatedAt: new Date(),
    };
  }

  async getCheckInOutStatistic(
    req: CheckInOutDashboardReq,
  ): Promise<CheckInOutDashboardRes[]> {
    const start = new Date(req.startDate);
    const end = new Date(req.endDate);
    const intervalMin = req.intervalMin > 0 ? req.intervalMin : 60;

    if (isNaN(start.getTime()) || isNaN(end.getTime()) || start >= end) {
      return [];
    }

    const now = new Date();
    const effectiveEnd = end > now ? now : end;
    if (start >= effectiveEnd) {
      return [];
    }

    // ponytail: raw SQL window function; upgrade path: snapshot table if log volume explodes
    const initialOccupancyRaw = await this.accessLogRepo.query<
      Array<{ count?: number | string }>
    >(
      `
      SELECT COUNT(*)::int AS count
      FROM (
        SELECT action,
               ROW_NUMBER() OVER (
                 PARTITION BY reader_id
                 ORDER BY occurred_at DESC, created_at DESC, id DESC
               ) AS rn
        FROM access_logs
        WHERE result = $1 AND occurred_at < $2
      ) t
      WHERE t.rn = 1 AND t.action = $3
      `,
      [AccessResult.SUCCESS, start, AccessAction.CHECK_IN],
    );

    let currentOccupancy = Number(initialOccupancyRaw[0]?.count ?? 0);

    // ponytail: generate_series bucket aggregation; upgrade path: continuous aggregate views (TimescaleDB)
    const step = `${intervalMin} minutes`;
    const rows = await this.accessLogRepo.query<RawBucketStats[]>(
      `
      SELECT
        b.bucket_start AS "startDate",
        COUNT(al.id) FILTER (WHERE al.action = $1 AND al.result = $2)::int AS "checkInCount",
        COUNT(al.id) FILTER (WHERE al.action IN ($3, $4) AND al.result = $2)::int AS "checkOutCount"
      FROM generate_series($5::timestamp, $6::timestamp, $7::interval) AS b(bucket_start)
      LEFT JOIN access_logs al
        ON al.occurred_at >= b.bucket_start
       AND al.occurred_at < LEAST(b.bucket_start + $7::interval, $6::timestamp)
      WHERE b.bucket_start < $6::timestamp
      GROUP BY b.bucket_start
      ORDER BY b.bucket_start ASC;
      `,
      [
        AccessAction.CHECK_IN,
        AccessResult.SUCCESS,
        AccessAction.CHECK_OUT,
        AccessAction.AUTO_CHECK_OUT,
        start,
        effectiveEnd,
        step,
      ],
    );

    const results: CheckInOutDashboardRes[] = [];

    for (const row of rows) {
      const bucketDate = new Date(row.startDate);
      if (bucketDate > now) {
        continue;
      }

      const checkInCount = Number(row.checkInCount || 0);
      const checkOutCount = Number(row.checkOutCount || 0);
      const peak = currentOccupancy + checkInCount;
      const lowest = Math.max(0, currentOccupancy - checkOutCount);
      currentOccupancy = Math.max(
        0,
        currentOccupancy + checkInCount - checkOutCount,
      );

      results.push({
        startDate: bucketDate,
        intervalMin,
        checkInCount,
        checkOutCount,
        peakPeopleCount: peak,
        lowestPeopleCount: lowest,
      });
    }

    return results;
  }
}
