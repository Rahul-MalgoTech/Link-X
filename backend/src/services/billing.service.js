export const billingPlans = [
  {
    id: 'free',
    name: 'Free',
    priceCents: 0,
    currency: 'INR',
    durationDays: null,
    features: ['Basic discovery', 'Matched chat', 'Public rooms'],
  },
  {
    id: 'premium',
    name: 'Premium',
    priceCents: 49900,
    currency: 'INR',
    durationDays: 30,
    features: ['More daily likes', 'Priority discovery', 'Private rooms'],
  },
  {
    id: 'plus',
    name: 'Plus',
    priceCents: 89900,
    currency: 'INR',
    durationDays: 30,
    features: ['Everything in Premium', 'Advanced filters', 'Room boosts'],
  },
  {
    id: 'linkx',
    name: 'Linkx',
    priceCents: 149900,
    currency: 'INR',
    durationDays: 30,
    features: ['Everything in Plus', 'VIP badge', 'Top placement'],
  },
];

export function paidPlan(planId) {
  return billingPlans.find((plan) => plan.id === planId && plan.id !== 'free');
}

export function freePlan() {
  return billingPlans.find((plan) => plan.id === 'free');
}

export function planExpiresAt(plan) {
  if (!plan.durationDays) return null;
  const date = new Date();
  date.setDate(date.getDate() + plan.durationDays);
  return date;
}
