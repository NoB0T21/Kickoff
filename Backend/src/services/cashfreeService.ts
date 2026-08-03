import crypto from 'crypto';
import { env } from '../config/env.js';

export interface CashfreeOrderResponse {
  cf_order_id: string;
  order_id: string;
  payment_session_id: string;
  order_status: string;
  order_amount: number;
}

export interface CashfreeRefundResponse {
  cf_refund_id: string;
  refund_id: string;
  refund_status: string;
  refund_amount: number;
}

class CashfreeService {
  private getHeaders() {
    return {
      'x-api-version': '2023-08-01',
      'x-client-id': env.CASHFREE_APP_ID,
      'x-client-secret': env.CASHFREE_SECRET_KEY,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  /**
   * Creates a Cashfree PG checkout order.
   */
  async createOrder(
    orderId: string,
    amount: number,
    userId: string,
    email: string,
    phone: string
  ): Promise<CashfreeOrderResponse> {
    const url = `${env.CASHFREE_BASE_URL}/orders`;
    const payload = {
      order_id: orderId,
      order_amount: amount,
      order_currency: 'INR',
      customer_details: {
        customer_id: userId,
        customer_phone: phone || '9999999999', // Cashfree requires a phone number
        customer_email: email,
      },
      order_meta: {
        // App handles status check locally or via poll, but redirect is required by Cashfree
        return_url: `https://sdk.cashfree.com/api/v2/payment/status?order_id=${orderId}`,
      },
    };

    console.log(`[CashfreeService] Creating order ${orderId} for amount ${amount}`);
    
    const response = await fetch(url, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`[CashfreeService] Create order failed: ${response.status} - ${errorText}`);
      throw new Error(`Cashfree order creation failed: ${response.statusText} (${errorText})`);
    }

    return (await response.json()) as CashfreeOrderResponse;
  }

  /**
   * Retrieves order status from Cashfree API.
   */
  async getOrderStatus(orderId: string): Promise<CashfreeOrderResponse> {
    const url = `${env.CASHFREE_BASE_URL}/orders/${orderId}`;

    const response = await fetch(url, {
      method: 'GET',
      headers: this.getHeaders(),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`[CashfreeService] Get order status failed: ${response.status} - ${errorText}`);
      throw new Error(`Cashfree order status lookup failed: ${response.statusText} (${errorText})`);
    }

    return (await response.json()) as CashfreeOrderResponse;
  }

  /**
   * Initiates a refund for an order.
   */
  async initiateRefund(
    orderId: string,
    refundId: string,
    amount: number,
    reason: string = 'User requested cancellation'
  ): Promise<CashfreeRefundResponse> {
    const url = `${env.CASHFREE_BASE_URL}/orders/${orderId}/refunds`;
    const payload = {
      refund_amount: amount,
      refund_id: refundId,
      refund_note: reason,
    };

    console.log(`[CashfreeService] Initiating refund ${refundId} for order ${orderId} (amount: ${amount})`);

    const response = await fetch(url, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`[CashfreeService] Refund failed: ${response.status} - ${errorText}`);
      throw new Error(`Cashfree refund initiation failed: ${response.statusText} (${errorText})`);
    }

    return (await response.json()) as CashfreeRefundResponse;
  }

  /**
   * Verifies Cashfree webhook signature authenticity.
   */
  verifyWebhookSignature(headers: Record<string, string | string[] | undefined>, rawBody: string): boolean {
    const signature = headers['x-webhook-signature'];
    const timestamp = headers['x-webhook-timestamp'];

    if (!signature || !timestamp) {
      console.error('[CashfreeService] Missing webhook signature headers');
      return false;
    }

    const sigString = `${timestamp}${rawBody}`;
    const secret = env.CASHFREE_WEBHOOK_SECRET;

    // Cashfree computes HMAC-SHA256 using the webhook secret, encoded in Base64
    const expectedSig = crypto
      .createHmac('sha256', secret)
      .update(sigString)
      .digest('base64');

    return signature === expectedSig;
  }
}

export const cashfreeService = new CashfreeService();
