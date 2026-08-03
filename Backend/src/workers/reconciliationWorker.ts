import { bookingService } from '../services/bookingService.js';

console.log('[ReconciliationWorker] Initializing background sweeps...');

// Sweep expired locks every 30 seconds
const LOCK_SWEEP_INTERVAL_MS = 30000;
setInterval(async () => {
  try {
    const sweptCount = await bookingService.sweepExpiredLocks();
    if (sweptCount > 0) {
      console.log(`[ReconciliationWorker] Swept ${sweptCount} expired locks`);
    }
  } catch (error) {
    console.error('[ReconciliationWorker] Error sweeping expired locks:', error);
  }
}, LOCK_SWEEP_INTERVAL_MS);

// Reconcile pending payments every 2 minutes (120000 ms)
const PAYMENT_RECONCILE_INTERVAL_MS = 120000;
setInterval(async () => {
  try {
    await bookingService.reconcilePendingPayments();
  } catch (error) {
    console.error('[ReconciliationWorker] Error in reconciliation runner:', error);
  }
}, PAYMENT_RECONCILE_INTERVAL_MS);
