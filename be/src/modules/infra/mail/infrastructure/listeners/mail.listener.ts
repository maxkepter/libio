import { Injectable, Logger } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import { UserRegisteredEvent } from '../../../../auth/domain/events/user-registered.event';
import { UserCreatedEvent } from '../../../../user/domain/events/user-created.event';
import { SendVerificationEmailHandler } from '../../application/handlers/send-verification-email.handler';
import { SendWelcomeEmailHandler } from '../../application/handlers/send-welcome-email.handler';

@Injectable()
export class MailListener {
  private readonly logger = new Logger(MailListener.name);

  constructor(
    private readonly sendVerificationEmailHandler: SendVerificationEmailHandler,
    private readonly sendWelcomeEmailHandler: SendWelcomeEmailHandler,
  ) {}

  @OnEvent(UserRegisteredEvent.EVENT_NAME, { async: true })
  async handleUserRegistered(event: UserRegisteredEvent): Promise<void> {
    this.logger.log(`Received UserRegisteredEvent: ${JSON.stringify(event)}`);
    return this.sendVerificationEmailHandler.handle(event);
  }

  @OnEvent(UserCreatedEvent.EVENT_NAME, { async: true })
  async handleUserCreated(event: UserCreatedEvent): Promise<void> {
    this.logger.log(`Received UserCreatedEvent: ${JSON.stringify(event)}`);
    return this.sendWelcomeEmailHandler.handle(event);
  }
}
