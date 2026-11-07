import { Injectable } from '@nestjs/common';
import { ReaderAccessHandler } from '../../application/handlers/reader-access.handler';
import { OnEvent } from '@nestjs/event-emitter';
import { ReaderAccessEvent } from '../../../checkin-out/domain/events/reader-access.event';

@Injectable()
export class DashboardListener {
  constructor(private readonly readerAccessHandler: ReaderAccessHandler) {}

  @OnEvent(ReaderAccessEvent.EVENT_NAME, { async: true })
  async handleReaderAccessEvent(event: ReaderAccessEvent): Promise<void> {
    await this.readerAccessHandler.handle(event);
  }
}
