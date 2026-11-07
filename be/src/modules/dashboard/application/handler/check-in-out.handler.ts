import { EventHandler } from '../../../../common/application/event/event-handler.interface';
import { ReaderAccessEvent } from '../../../checkin-out/domain/events/reader-access.event';

export class CheckInOutHandler implements EventHandler<ReaderAccessEvent> {
  async handle(event: ReaderAccessEvent): Promise<void> {}
}
