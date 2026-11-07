import { Injectable } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';

import { InternalEventBus } from '../application/internal-event-bus.interface';
import { DomainEvent } from '../../../../common/domain/domain-event';

@Injectable()
export class EventEmitterService implements InternalEventBus {
  constructor(private readonly eventEmitter: EventEmitter2) {}

  async publish(event: DomainEvent): Promise<void> {
    await this.eventEmitter.emitAsync(event.getEventName(), event);
  }
}
