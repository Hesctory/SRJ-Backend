# Enrollment Payments — Backend Contract

Endpoints required by the enrollment payments feature (3-step flow: select student → select enrollment → manage debts & pay).

> Filter parameters are sent by `simpleRestProvider` as a JSON-encoded `filter` query param:
> `GET /api/enrollment-debts?filter={"enrollmentId":7}&_start=0&_end=10`
> The backend must parse `filter` as JSON and apply each key as a WHERE condition.

---

## 1. Enrollment Debts (new resource)

`GET /api/enrollment-debts`
`GET /api/enrollment-debts/:id`

| Filter param | Type | Required | Description |
|---|---|---|---|
| `enrollmentId` | number | yes | Returns all debts for this enrollment |

**Response item:**
```json
{
  "id": 1,
  "enrollmentId": 7,
  "description": "Mensualidad Marzo",
  "totalAmount": 350.00,
  "paidAmount": 0.00,
  "dueDate": "2025-03-31",
  "status": "pending"
}
```

`status` possible values: `"pending"`, `"partially_paid"`, `"overdue"`, `"paid"`, `"cancelled"`

---

## 2. Debt Installments (new resource)

`GET /api/debt-installments`
`GET /api/debt-installments/:id`

| Filter param | Type | Required | Description |
|---|---|---|---|
| `debtId` | number | yes | Returns all registered payments for this debt |

**Response item:**
```json
{
  "id": 10,
  "debtId": 1,
  "amount": 175.00,
  "date": "2025-03-10",
  "paymentMethodName": "Efectivo",
  "reference": "REC-001"
}
```

`reference` is optional.

---

## 3. Payment Methods (new resource)

`GET /api/payment-methods`

No filters. Returns all available payment methods.

**Response item:**
```json
{
  "id": 1,
  "name": "Efectivo"
}
```

---

## 4. Payment Preview (new custom action)

`POST /api/payment-preview`

Calculates how the payment amount would be allocated across debts **without saving anything**. Returns a token that must be passed to `/api/payments` to confirm.

**Request body:**
```json
{
  "enrollmentId": 7,
  "enrollmentDebtId": 1,
  "amount": 350.00,
  "paymentMethodId": 1,
  "date": "2025-05-22"
}
```

`enrollmentDebtId` is **optional** — omit it for a "Pago rápido" (no specific debt targeted; the backend distributes the amount across pending debts as it sees fit).

**Response:**
```json
{
  "previewToken": "abc123xyz",
  "paymentPlan": {
    "lines": [
      {
        "debtId": 1,
        "description": "Mensualidad Marzo",
        "allocated": 350.00,
        "remaining": 0.00
      }
    ],
    "totalAllocated": 350.00,
    "change": 0.00
  }
}
```

`previewToken` must be a short-lived token (suggested TTL: 5 min) that identifies this specific preview so `/api/payments` can confirm it without re-sending all parameters.

---

## 5. Payments (new custom action)

`POST /api/payments`

Confirms and saves a payment. Requires the `previewToken` obtained from `/api/payment-preview`.

**Request body:**
```json
{
  "previewToken": "abc123xyz"
}
```

**Response:**
```json
{
  "id": 99,
  "paymentPlan": {
    "lines": [
      {
        "debtId": 1,
        "description": "Mensualidad Marzo",
        "allocated": 350.00,
        "remaining": 0.00
      }
    ],
    "totalAllocated": 350.00,
    "change": 0.00
  }
}
```

After this call, the relevant `enrollment-debts` records must reflect the updated `paidAmount` and `status`, and a new `debt-installments` record must exist.

---

## Summary

| # | Method | Endpoint |
|---|---|---|
| 1 | GET | `/api/enrollment-debts` |
| 2 | GET | `/api/debt-installments` |
| 3 | GET | `/api/payment-methods` |
| 4 | POST | `/api/payment-preview` |
| 5 | POST | `/api/payments` |
