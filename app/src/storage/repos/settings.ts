/**
 * storage/repos/settings.ts — repo settings (id=1, BYOK nằm ở đây — Q-03).
 *
 * updatePartial chỉ nhận field qua whitelist: patch field lạ bị bỏ qua trong
 * im lặng sẽ thành bug khó dò, nên ném lỗi — đúng điều cấm "không nuốt im lặng".
 *
 * `await` mọi lời gọi appDb: DB nằm trong Worker (facade RPC — xem db.ts).
 */
import type { SettingsRepository } from "../../domain/repositories";
import type { Cefr, Settings } from "../../domain/types";
import type { AppDb } from "../db";

interface SettingsSql {
  id: number;
  cefr_level: string;
  daily_new_limit: number | bigint;
  ai_provider: string;
  ai_base_url: string;
  ai_api_key: string | null;
  ai_model: string | null;
  request_retention: number;
  maximum_interval: number | bigint;
  enable_fuzz: number | bigint;
  day_cutoff_hour: number | bigint;
  fsrs_params: string | null;
  fsrs_version: string | null;
}

/** key camel → cột SQL — whitelist duy nhất cho updatePartial. */
const COLUMN_MAP: Record<string, string> = {
  cefrLevel: "cefr_level",
  dailyNewLimit: "daily_new_limit",
  aiProvider: "ai_provider",
  aiBaseUrl: "ai_base_url",
  aiApiKey: "ai_api_key",
  aiModel: "ai_model",
  requestRetention: "request_retention",
  maximumInterval: "maximum_interval",
  enableFuzz: "enable_fuzz",
  dayCutoffHour: "day_cutoff_hour",
};

function map(row: SettingsSql): Settings {
  return {
    cefrLevel: row.cefr_level as Cefr,
    dailyNewLimit: Number(row.daily_new_limit),
    aiProvider: row.ai_provider,
    aiBaseUrl: row.ai_base_url,
    aiApiKey: row.ai_api_key,
    aiModel: row.ai_model,
    requestRetention: row.request_retention,
    maximumInterval: Number(row.maximum_interval),
    enableFuzz: row.enable_fuzz === 1,
    dayCutoffHour: Number(row.day_cutoff_hour),
    fsrsParams: row.fsrs_params,
    fsrsVersion: row.fsrs_version,
  };
}

function toSql(): string {
  return `select id, cefr_level, daily_new_limit, ai_provider, ai_base_url, ai_api_key, ai_model,
                 request_retention, maximum_interval, enable_fuzz, day_cutoff_hour,
                 fsrs_params, fsrs_version
          from settings where id = 1`;
}

export function createSettingsRepo(appDb: AppDb): SettingsRepository {
  return {
    async get() {
      const row = await appDb.get<SettingsSql>(toSql());
      if (!row) throw new Error("settings row (id=1) không tồn tại — seed chưa chạy");
      return map(row);
    },
    async updatePartial(patch) {
      const sets: string[] = [];
      const bind: (string | number)[] = [];
      for (const [key, value] of Object.entries(patch)) {
        if (value === undefined) continue;
        const col = COLUMN_MAP[key];
        if (!col) throw new Error(`updatePartial: field không trong whitelist: "${key}"`);
        sets.push(`${col} = ?`);
        bind.push(typeof value === "boolean" ? (value ? 1 : 0) : (value as string | number));
      }
      if (sets.length > 0) {
        await appDb.exec(`update settings set ${sets.join(", ")} where id = 1`, bind);
      }
      const row = await appDb.get<SettingsSql>(toSql());
      if (!row) throw new Error("settings row biến mất sau update");
      return map(row);
    },
  };
}
