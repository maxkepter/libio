import { DomainEvent } from '../../../../common/domain/domain-event';
import { AccessAction } from '../../../access/domain/enums/access-action.enum';
import { AccessMethod } from '../../../access/domain/enums/access-method.enum';

export class ReaderAccessEvent extends DomainEvent {
  static readonly EVENT_NAME = 'reader.access';

  constructor(
    public readonly action: AccessAction,
    public readonly readerId: string,
    public readonly deviceId: string,
    public readonly accessLogId: string,
    public readonly occurredAt: Date,
    public readonly readerName: string,
    public readonly gateId: string,
    public readonly gateName: string,
    public readonly method: AccessMethod,
  ) {
    super();
  }

  getEventName(): string {
    return ReaderAccessEvent.EVENT_NAME;
  }
}
