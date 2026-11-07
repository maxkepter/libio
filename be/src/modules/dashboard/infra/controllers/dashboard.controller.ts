import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Query,
  Sse,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { JwtGuard } from '../../../auth/infra/guard/jwt.guard';
import { RoleGuard } from '../../../auth/infra/guard/role.guard';
import { Roles } from '../../../auth/infra/decorators/role.decorator';
import { Role } from '../../../user/domain/enums/role.enum';
import { DashboardService } from '../../application/services/dashboard.service';
import { CheckInOutDashboardReq } from '../../dto/req.dto';
import {
  CheckInOutDashboardRes,
  OccupancyDashboardRes,
} from '../../dto/res.dto';
import { DashboardStreamService } from '../../application/services/dashboard-stream.service';
import { Observable } from 'rxjs';

@ApiTags('Dashboard')
@ApiBearerAuth('access-token')
@UseGuards(JwtGuard, RoleGuard)
@Roles(Role.ADMIN, Role.STAFF)
@Controller('dashboard')
export class DashboardController {
  constructor(
    private readonly dashboardService: DashboardService,
    private readonly dashboardStreamServide: DashboardStreamService,
  ) {}

  @Get('occupancy')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Lấy số người hiện tại trong thư viện và tình trạng sức chứa',
  })
  @ApiResponse({
    status: HttpStatus.OK,
    description: 'Thông tin sức chứa và số lượng người hiện tại',
    type: OccupancyDashboardRes,
  })
  getOccupancy(): Promise<OccupancyDashboardRes> {
    return this.dashboardService.getCurrentOccupancy();
  }

  @Get('check-in-out-statistic')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Lấy thống kê lượt Check-in / Check-out theo khoảng thời gian',
  })
  @ApiResponse({
    status: HttpStatus.OK,
    description: 'Danh sách các bucket thống kê lượt ra/vào và lượng người',
    type: [CheckInOutDashboardRes],
  })
  getCheckInOutStatistic(
    @Query() query: CheckInOutDashboardReq,
  ): Promise<CheckInOutDashboardRes[]> {
    return this.dashboardService.getCheckInOutStatistic(query);
  }

  @Sse('check-in-out/events')
  getCheckInOutEvents(): Observable<MessageEvent> {
    return this.dashboardStreamServide.getReaderAccessEvents();
  }
}
