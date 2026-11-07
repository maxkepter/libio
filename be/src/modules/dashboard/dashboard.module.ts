import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LibraryModule } from '../library/library.module';
import { AccessLog } from '../access/domain/entities/access-log.entity';
import { DashboardService } from './application/services/dashboard.service';
import { DashboardController } from './infra/controllers/dashboard.controller';
import { DashboardListener } from './infra/listeners/dashboard.listiner';
import { DashboardStreamService } from './application/services/dashboard-stream.service';
import { ReaderAccessHandler } from './application/handlers/reader-access.handler';

@Module({
  imports: [LibraryModule, ConfigModule, TypeOrmModule.forFeature([AccessLog])],
  controllers: [DashboardController],
  providers: [
    DashboardService,
    DashboardListener,
    DashboardStreamService,
    ReaderAccessHandler,
  ],
  exports: [DashboardService],
})
export class DashboardModule {}
