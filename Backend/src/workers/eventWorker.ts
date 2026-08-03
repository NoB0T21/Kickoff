import { eventService } from '../services/eventService.js';

console.log('[EventWorker] Initializing background autocomplete sweeps...');

// Run autocomplete check every 10 seconds
const AUTOCOMPLETE_INTERVAL_MS = 10000;
setInterval(async () => {
  try {
    const counts = await eventService.triggerAutoComplete();
    if (counts.completedLive > 0 || counts.completedScheduled > 0) {
      console.log(
        `[EventWorker] Autocompleted ${counts.completedLive} live events and ${counts.completedScheduled} scheduled fallback events.`
      );
    }
  } catch (error) {
    console.error('[EventWorker] Error autocompleting events:', error);
  }
}, AUTOCOMPLETE_INTERVAL_MS);
