const apiBase = '/api';
const tokenKey = 'linkx_admin_token';
const state = {
  token: localStorage.getItem(tokenKey),
  user: null,
  events: [],
  editingId: null,
};

const $ = (selector) => document.querySelector(selector);
const loginView = $('#login-view');
const dashboardView = $('#dashboard-view');
const eventGrid = $('#event-grid');
const eventModal = $('#event-modal');

async function api(path, options = {}) {
  const response = await fetch(`${apiBase}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(state.token ? { Authorization: `Bearer ${state.token}` } : {}),
      ...options.headers,
    },
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.message || 'Request failed');
  return data;
}

function setBusy(button, busy, label) {
  if (!button.dataset.label) button.dataset.label = button.textContent;
  button.disabled = busy;
  button.textContent = busy ? label : button.dataset.label;
}

function showToast(message) {
  const toast = $('#toast');
  toast.textContent = message;
  toast.classList.remove('hidden');
  clearTimeout(showToast.timer);
  showToast.timer = setTimeout(() => toast.classList.add('hidden'), 2600);
}

function showLogin(error = '') {
  state.token = null;
  state.user = null;
  localStorage.removeItem(tokenKey);
  dashboardView.classList.add('hidden');
  loginView.classList.remove('hidden');
  $('#login-error').textContent = error;
}

async function enterDashboard() {
  const data = await api('/users/me');
  if (!data.user?.isAdmin) {
    throw new Error('This phone number is not an administrator.');
  }
  state.user = data.user;
  loginView.classList.add('hidden');
  dashboardView.classList.remove('hidden');
  $('#admin-phone').textContent =
    `${data.user.countryCode || ''} ${data.user.phoneNumber || ''}`.trim();
  await loadEvents();
}

$('#login-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const button = $('#login-button');
  const countryCode = $('#country-code').value.trim();
  const phoneNumber = $('#phone-number').value.trim();
  const otp = $('#otp').value.trim();
  $('#login-error').textContent = '';
  setBusy(button, true, 'Signing in...');
  try {
    await api('/auth/request-otp', {
      method: 'POST',
      body: JSON.stringify({ countryCode, phoneNumber }),
    });
    const result = await api('/auth/verify-otp', {
      method: 'POST',
      body: JSON.stringify({ countryCode, phoneNumber, otp }),
    });
    state.token = result.token;
    localStorage.setItem(tokenKey, state.token);
    await enterDashboard();
  } catch (error) {
    showLogin(error.message);
  } finally {
    setBusy(button, false, '');
  }
});

async function loadEvents() {
  $('#loading-state').textContent = 'Loading events...';
  $('#loading-state').classList.remove('hidden');
  $('#empty-state').classList.add('hidden');
  eventGrid.innerHTML = '';
  try {
    const data = await api('/events/admin?limit=50');
    state.events = data.events || [];
    renderEvents();
  } catch (error) {
    if (/token|auth|admin/i.test(error.message)) {
      showLogin(error.message);
      return;
    }
    $('#loading-state').textContent = error.message;
  }
}

function filteredEvents() {
  const query = $('#search-input').value.trim().toLowerCase();
  const status = $('#status-filter').value;
  return state.events.filter((event) => {
    const haystack = `${event.title} ${event.venue}`.toLowerCase();
    return (
      (!query || haystack.includes(query)) &&
      (status === 'all' || event.status === status)
    );
  });
}

function renderEvents() {
  $('#loading-state').classList.add('hidden');
  const events = filteredEvents();
  $('#total-events').textContent = state.events.length;
  $('#published-events').textContent = state.events.filter(
    (event) => event.status === 'published',
  ).length;
  $('#total-attendees').textContent = state.events.reduce(
    (total, event) => total + event.attendeeCount,
    0,
  );
  $('#empty-state').classList.toggle('hidden', events.length > 0);
  eventGrid.innerHTML = events.map(eventCard).join('');
}

function eventCard(event) {
  const date = new Date(event.startAt);
  const price = event.priceCents
    ? `INR ${(event.priceCents / 100).toLocaleString('en-IN')}`
    : 'Free';
  const image = event.coverImageUrl
    ? `<img src="${escapeHtml(event.coverImageUrl)}" alt="">`
    : '';
  const cancelled = event.status === 'cancelled';
  return `
    <article class="event-card">
      <div class="event-image">
        ${image}
        <span class="status-badge ${cancelled ? 'cancelled' : ''}">${escapeHtml(event.status)}</span>
      </div>
      <div class="event-body">
        <div class="event-title-row">
          <h4>${escapeHtml(event.title)}</h4>
          <strong>${price}</strong>
        </div>
        <div class="event-meta">
          <span>Date: ${date.toLocaleString([], { dateStyle: 'medium', timeStyle: 'short' })}</span>
          <span>Venue: ${escapeHtml(event.venue || 'Online')}</span>
        </div>
        <div class="event-footer">
          <strong>${event.attendeeCount}/${event.capacity} attending</strong>
          <div class="card-actions">
            <button class="small-button" data-edit="${event.id}">Edit</button>
            <button class="small-button ${cancelled ? '' : 'danger'}" data-status="${event.id}">
              ${cancelled ? 'Republish' : 'Cancel'}
            </button>
          </div>
        </div>
      </div>
    </article>`;
}

function escapeHtml(value) {
  return String(value || '').replace(
    /[&<>"']/g,
    (character) =>
      ({
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;',
      })[character],
  );
}

function toLocalInput(dateValue) {
  if (!dateValue) return '';
  const date = new Date(dateValue);
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
  return local.toISOString().slice(0, 16);
}

function openModal(event = null) {
  state.editingId = event?.id || null;
  $('#modal-title').textContent = event ? 'Edit event' : 'Create event';
  $('#save-button').textContent = event ? 'Save changes' : 'Publish event';
  $('#save-button').dataset.label = $('#save-button').textContent;
  $('#event-title').value = event?.title || '';
  $('#event-description').value = event?.description || '';
  $('#event-image').value = event?.coverImageUrl || '';
  $('#event-venue').value = event?.venue || '';
  $('#event-start').value = event
    ? toLocalInput(event.startAt)
    : toLocalInput(Date.now() + 86400000);
  $('#event-end').value = event ? toLocalInput(event.endAt) : '';
  $('#event-capacity').value = event?.capacity || 100;
  $('#event-price').value = event ? event.priceCents / 100 : 0;
  $('#event-error').textContent = '';
  eventModal.classList.remove('hidden');
  document.body.style.overflow = 'hidden';
}

function closeModal() {
  eventModal.classList.add('hidden');
  document.body.style.overflow = '';
  state.editingId = null;
}

$('#event-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const button = $('#save-button');
  const editingId = state.editingId;
  const startValue = $('#event-start').value;
  const endValue = $('#event-end').value;
  if (endValue && new Date(endValue) <= new Date(startValue)) {
    $('#event-error').textContent = 'End time must be after start time.';
    return;
  }
  const payload = {
    title: $('#event-title').value.trim(),
    description: $('#event-description').value.trim(),
    coverImageUrl: $('#event-image').value.trim(),
    venue: $('#event-venue').value.trim(),
    startAt: new Date(startValue).toISOString(),
    ...(endValue
      ? { endAt: new Date(endValue).toISOString() }
      : editingId
        ? { endAt: null }
        : {}),
    capacity: Number($('#event-capacity').value),
    priceCents: Math.round(Number($('#event-price').value) * 100),
    currency: 'INR',
  };
  $('#event-error').textContent = '';
  setBusy(button, true, 'Saving...');
  try {
    if (editingId) {
      await api(`/events/${editingId}`, {
        method: 'PATCH',
        body: JSON.stringify(payload),
      });
    } else {
      await api('/events', {
        method: 'POST',
        body: JSON.stringify(payload),
      });
    }
    closeModal();
    await loadEvents();
    showToast(editingId ? 'Event updated' : 'Event published');
  } catch (error) {
    $('#event-error').textContent = error.message;
  } finally {
    setBusy(button, false, '');
  }
});

eventGrid.addEventListener('click', async (event) => {
  const editId = event.target.dataset.edit;
  const statusId = event.target.dataset.status;
  if (editId) {
    openModal(state.events.find((item) => item.id === editId));
  }
  if (!statusId) return;
  const item = state.events.find((candidate) => candidate.id === statusId);
  if (!item) return;
  try {
    if (item.status === 'cancelled') {
      await api(`/events/${item.id}`, {
        method: 'PATCH',
        body: JSON.stringify({ status: 'published' }),
      });
      showToast('Event republished');
    } else {
      if (!window.confirm(`Cancel "${item.title}"?`)) return;
      await api(`/events/${item.id}`, { method: 'DELETE' });
      showToast('Event cancelled');
    }
    await loadEvents();
  } catch (error) {
    showToast(error.message);
  }
});

$('#create-button').addEventListener('click', () => openModal());
$('#search-input').addEventListener('input', renderEvents);
$('#status-filter').addEventListener('change', renderEvents);
$('#logout-button').addEventListener('click', () => showLogin());
$('#menu-button').addEventListener('click', () =>
  $('.sidebar').classList.toggle('open'),
);
document
  .querySelectorAll('[data-close-modal]')
  .forEach((button) => button.addEventListener('click', closeModal));
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') closeModal();
});

if (state.token) {
  enterDashboard().catch((error) => showLogin(error.message));
} else {
  showLogin();
}
