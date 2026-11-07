import { Injectable } from '@nestjs/common';
import { Observable, Subject } from 'rxjs';
import { BaseService } from '../../../../common/application/service/base.service';

@Injectable()
export class DashboardStreamService extends BaseService {
  private readonly readerAccessEvents = new Subject<MessageEvent>();

  constructor() {
    super(DashboardStreamService.name);
  }

  getReaderAccessEvents(): Observable<MessageEvent> {
    return this.readerAccessEvents.asObservable();
  }

  publishReaderAccessEvent(event: MessageEvent): void {
    this.logger.debug(
      `Publishing ReaderAccessEvent: ${JSON.stringify({
        data: event.data,
        type: event.type,
        lastEventId: event.lastEventId,
      })}`,
    );

    this.readerAccessEvents.next(event);
  }
}
