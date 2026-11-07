export abstract class DomainEvent {
  readonly occuredOn: Date;

  static readonly EVENT_NAME: string;

  constructor() {
    this.occuredOn = new Date();
  }

  abstract getEventName(): string;

}
