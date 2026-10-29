import http from '@ohos.net.http';

/** Current conditions for the demo city, from the keyless Open-Meteo API. */
export interface WeatherNow {
  ok: boolean;
  city: string;
  temperature: number;
  text: string;
  tip: string;
}

interface OpenMeteoCurrent {
  temperature_2m: number;
  weather_code: number;
}

interface OpenMeteoResponse {
  current: OpenMeteoCurrent;
}

/** 郑州 — the competition host city; a fixed demo location, no permission needed. */
const CITY_NAME: string = '郑州';
const LATITUDE: string = '34.7466';
const LONGITUDE: string = '113.6254';

function weatherText(code: number): string {
  if (code === 0) {
    return '晴';
  }
  if (code <= 2) {
    return '多云';
  }
  if (code === 3) {
    return '阴';
  }
  if (code === 45 || code === 48) {
    return '有雾';
  }
  if (code >= 51 && code <= 57) {
    return '毛毛雨';
  }
  if (code >= 61 && code <= 67) {
    return '下雨';
  }
  if (code >= 71 && code <= 77) {
    return '下雪';
  }
  if (code >= 80 && code <= 82) {
    return '阵雨';
  }
  if (code >= 95) {
    return '雷雨';
  }
  return '天气平稳';
}

/** Rule-based first so the card still says something useful without any model. */
function weatherTip(temperature: number, code: number): string {
  if (code >= 51) {
    return '有降水，通勤换成公交或地铁更合适，别硬骑车。';
  }
  if (temperature >= 30) {
    return '高温天，空调负荷最大，今天省电最划算。';
  }
  if (temperature <= 5) {
    return '气温低，取暖耗电上升，注意别长时间开窗散热。';
  }
  if (code <= 1) {
    return '天气不错，通勤换成步行或骑行最划算。';
  }
  return '天气平稳，按平时的节奏记录就好。';
}

/** Offline fallback so the card still works when the network is unreachable. */
export function manualWeather(kind: string): WeatherNow {
  if (kind === 'rain') {
    return { ok: true, city: '手动', temperature: 16, text: '下雨', tip: weatherTip(16, 61) };
  }
  if (kind === 'hot') {
    return { ok: true, city: '手动', temperature: 33, text: '高温', tip: weatherTip(33, 0) };
  }
  if (kind === 'cold') {
    return { ok: true, city: '手动', temperature: 2, text: '寒冷', tip: weatherTip(2, 0) };
  }
  if (kind === 'cloud') {
    return { ok: true, city: '手动', temperature: 20, text: '多云', tip: weatherTip(20, 2) };
  }
  return { ok: true, city: '手动', temperature: 22, text: '晴', tip: weatherTip(22, 0) };
}

export async function fetchWeather(): Promise<WeatherNow> {  const request = http.createHttp();
  try {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${LATITUDE}&longitude=${LONGITUDE}` +
      '&current=temperature_2m,weather_code&timezone=Asia%2FShanghai';
    const response = await request.request(url, {
      method: http.RequestMethod.GET,
      connectTimeout: 12000,
      readTimeout: 12000
    });
    if (response.responseCode !== 200) {
      throw new Error(`天气服务返回 HTTP ${response.responseCode}`);
    }
    const parsed = JSON.parse(response.result as string) as OpenMeteoResponse;
    const temperature = Math.round(parsed.current.temperature_2m);
    const code = parsed.current.weather_code;
    return {
      ok: true,
      city: CITY_NAME,
      temperature: temperature,
      text: weatherText(code),
      tip: weatherTip(temperature, code)
    };
  } catch (error) {
    return { ok: false, city: CITY_NAME, temperature: 0, text: '', tip: '' };
  } finally {
    request.destroy();
  }
}
