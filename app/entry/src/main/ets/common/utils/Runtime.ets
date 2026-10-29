import util from '@ohos.util';
import { Clock, Id, IdGenerator, LocalDate, RequestId } from '../contracts/Common';
import { localDateFromDate } from './Dates';

export class SystemClock implements Clock {
  nowMs(): number {
    return Date.now();
  }

  today(): LocalDate {
    return localDateFromDate(new Date(this.nowMs()));
  }
}

export class UuidGenerator implements IdGenerator {
  newId(): Id {
    return util.generateRandomUUID(true);
  }
}

export function newRequestId(ids: IdGenerator): RequestId {
  return ids.newId();
}
