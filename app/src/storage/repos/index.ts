/**
 * storage/repos/index.ts — lắp ráp toàn bộ repo thật trên một AppDb.
 */
import type { ReadoRepos } from "../../domain/repositories";
import type { AppDb } from "../db";
import { createAnalysesRepo } from "./analyses";
import { createCardsRepo } from "./cards";
import { createCollectionsRepo } from "./collections";
import { createReviewLogsRepo } from "./reviewLogs";
import { createSettingsRepo } from "./settings";
import { createVocabItemsRepo } from "./vocabItems";

export function createRepos(appDb: AppDb): ReadoRepos {
  return {
    collections: createCollectionsRepo(appDb),
    vocabItems: createVocabItemsRepo(appDb),
    cards: createCardsRepo(appDb),
    logs: createReviewLogsRepo(appDb),
    settings: createSettingsRepo(appDb),
    analyses: createAnalysesRepo(appDb),
  };
}