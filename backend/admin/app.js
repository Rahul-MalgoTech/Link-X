const apiBase = '/api';
const tokenKey = 'linkx_admin_token';
const state = {
  token: localStorage.getItem(tokenKey),
  user: null,
  events: [],
  editingId: null,
  users: [],
  usersPage: 1,
  usersHasMore: false,
  editingUserId: null,
  selectedUserPhotos: [],
  hostApplications: [],
  activeView: 'events',
};

const $ = (selector) => document.querySelector(selector);
const loginView = $('#login-view');
const dashboardView = $('#dashboard-view');
const eventGrid = $('#event-grid');
const eventModal = $('#event-modal');
const userModal = $('#user-modal');
const userTableBody = $('#user-table-body');

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

async function apiForm(path, formData) {
  const response = await fetch(`${apiBase}${path}`, {
    method: 'POST',
    headers: state.token ? { Authorization: `Bearer ${state.token}` } : {},
    body: formData,
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.message || 'Upload failed');
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
  await setView(state.activeView);
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

function toDateInput(dateValue) {
  if (!dateValue) return '';
  const date = new Date(dateValue);
  return Number.isNaN(date.getTime()) ? '' : date.toISOString().slice(0, 10);
}

function setChecked(selector, value) {
  $(selector).checked = value !== false;
}

function optionalNumber(selector) {
  const value = $(selector).value.trim();
  return value === '' ? null : Number(value);
}

async function setView(view) {
  state.activeView = view;
  document
    .querySelectorAll('.admin-view')
    .forEach((element) => element.classList.add('hidden'));
  $(`#${view}-view`).classList.remove('hidden');
  document.querySelectorAll('[data-view]').forEach((button) => {
    button.classList.toggle('active', button.dataset.view === view);
  });
  $('.sidebar').classList.remove('open');
  if (view === 'users') {
    await loadUsers();
  } else if (view === 'hosts') {
    await loadHostApplications();
  } else {
    await loadEvents();
  }
}

async function loadHostApplications() {
  $('#hosts-loading').textContent = 'Loading host requests...';
  $('#hosts-loading').classList.remove('hidden');
  $('#hosts-empty').classList.add('hidden');
  $('#host-request-grid').innerHTML = '';
  const status = $('#host-status-filter').value;
  const query = new URLSearchParams({ limit: '80' });
  if (status) query.set('status', status);

  try {
    const data = await api(`/hosts/admin/applications?${query}`);
    state.hostApplications = data.applications || [];
    renderHostApplications(data);
  } catch (error) {
    if (/token|auth|admin/i.test(error.message)) {
      showLogin(error.message);
      return;
    }
    $('#hosts-loading').textContent = error.message;
  }
}

function renderHostApplications(data = {}) {
  const summary = data.summary || {};
  $('#pending-hosts').textContent = summary.pending || 0;
  $('#approved-hosts').textContent = summary.approved || 0;
  $('#rejected-hosts').textContent = summary.rejected || 0;
  $('#hosts-loading').classList.add('hidden');
  $('#hosts-empty').classList.toggle(
    'hidden',
    state.hostApplications.length > 0,
  );
  $('#host-request-grid').innerHTML = state.hostApplications
    .map(hostApplicationCard)
    .join('');
}

function hostApplicationCard(application) {
  const applicant = application.user || {};
  const media = application.media || {};
  const mediaPreview =
    media.resourceType === 'video'
      ? `<video src="${escapeHtml(media.url)}" controls playsinline></video>`
      : media.url
        ? `<img src="${escapeHtml(media.url)}" alt="">`
        : '<div class="host-media-empty">No media</div>';
  const avatar = applicant.avatarUrl
    ? `<img src="${escapeHtml(applicant.avatarUrl)}" alt="">`
    : `<span>${escapeHtml((applicant.name || 'H')[0].toUpperCase())}</span>`;
  const canReview = application.status === 'pending';
  return `
    <article class="host-request-card">
      <div class="host-request-media">
        ${mediaPreview}
        <span class="status-badge ${escapeHtml(application.status)}">${escapeHtml(application.status)}</span>
      </div>
      <div class="host-request-body">
        <div class="host-applicant">
          <div class="host-avatar">${avatar}</div>
          <div>
            <strong>${escapeHtml(application.displayName)}</strong>
            <small>${escapeHtml(applicant.name || 'Linkx user')} · ${escapeHtml(`${applicant.countryCode || ''} ${applicant.phoneNumber || ''}`.trim())}</small>
          </div>
        </div>
        <p>${escapeHtml(application.bio)}</p>
        <div class="host-chip-row">
          ${(application.topics || []).map((topic) => `<span>${escapeHtml(topic)}</span>`).join('')}
          ${(application.languages || []).map((language) => `<span>${escapeHtml(language)}</span>`).join('')}
        </div>
        ${
          application.experience
            ? `<div class="host-experience"><strong>Experience</strong><span>${escapeHtml(application.experience)}</span></div>`
            : ''
        }
        ${
          application.adminNote
            ? `<div class="host-note"><strong>Admin note</strong><span>${escapeHtml(application.adminNote)}</span></div>`
            : ''
        }
        <div class="event-footer">
          <strong>${application.createdAt ? new Date(application.createdAt).toLocaleString([], { dateStyle: 'medium', timeStyle: 'short' }) : 'New request'}</strong>
          <div class="card-actions">
            <button class="small-button" data-approve-host="${escapeHtml(application.id)}" ${canReview ? '' : 'disabled'}>Approve</button>
            <button class="small-button danger" data-reject-host="${escapeHtml(application.id)}" ${canReview ? '' : 'disabled'}>Reject</button>
          </div>
        </div>
      </div>
    </article>`;
}

async function reviewHostApplication(applicationId, status) {
  const note =
    status === 'rejected'
      ? window.prompt('Optional rejection note for the user:', '') || ''
      : window.prompt('Optional approval note:', '') || '';
  try {
    await api(`/hosts/admin/applications/${applicationId}`, {
      method: 'PATCH',
      body: JSON.stringify({ status, adminNote: note }),
    });
    showToast(status === 'approved' ? 'Host approved' : 'Host rejected');
    await loadHostApplications();
  } catch (error) {
    showToast(error.message);
  }
}

async function loadUsers({ resetPage = false } = {}) {
  if (resetPage) state.usersPage = 1;
  $('#users-loading').textContent = 'Loading users...';
  $('#users-loading').classList.remove('hidden');
  $('#users-empty').classList.add('hidden');
  $('#user-table-wrap').classList.add('hidden');
  const query = new URLSearchParams({
    page: String(state.usersPage),
    limit: '20',
  });
  const search = $('#user-search').value.trim();
  const role = $('#user-role-filter').value;
  const accountStatus = $('#user-status-filter').value;
  if (search) query.set('search', search);
  if (role) query.set('role', role);
  if (accountStatus) query.set('accountStatus', accountStatus);

  try {
    const data = await api(`/users/admin-users?${query}`);
    state.users = data.users || [];
    state.usersHasMore = data.pagination?.hasMore === true;
    renderUsers(data);
  } catch (error) {
    if (/token|auth|admin/i.test(error.message)) {
      showLogin(error.message);
      return;
    }
    $('#users-loading').textContent = error.message;
  }
}

function renderUsers(data) {
  const summary = data.summary || {};
  $('#total-users').textContent = summary.total || 0;
  $('#active-users').textContent = summary.active || 0;
  $('#onboarded-users').textContent = summary.onboarded || 0;
  $('#suspended-users').textContent = summary.suspended || 0;
  $('#users-loading').classList.add('hidden');
  $('#users-empty').classList.toggle('hidden', state.users.length > 0);
  $('#user-table-wrap').classList.toggle('hidden', state.users.length === 0);
  userTableBody.innerHTML = state.users.map(userRow).join('');
  $('#users-page-label').textContent =
    `Page ${state.usersPage} · ${data.pagination?.total || 0} result${data.pagination?.total === 1 ? '' : 's'}`;
  $('#users-prev').disabled = state.usersPage <= 1;
  $('#users-next').disabled = !state.usersHasMore;
}

function userRow(user) {
  const image = user.photos?.[0]?.url
    ? `<img src="${escapeHtml(user.photos[0].url)}" alt="">`
    : `<span class="user-placeholder">${escapeHtml((user.firstName || 'U')[0].toUpperCase())}</span>`;
  const name = user.firstName || 'Unnamed user';
  const joined = user.createdAt
    ? new Date(user.createdAt).toLocaleDateString()
    : 'Unknown';
  return `
    <tr>
      <td><div class="user-cell">${image}<div><strong>${escapeHtml(name)}</strong><small>${escapeHtml(user.identity || 'Identity not set')}</small></div></div></td>
      <td>${escapeHtml(`${user.countryCode || ''} ${user.phoneNumber || ''}`.trim())}</td>
      <td><span class="pill ${escapeHtml(user.accountStatus)}">${escapeHtml(user.accountStatus)}</span>${user.isAdmin ? '<span class="pill admin">Admin</span>' : ''}</td>
      <td><span class="pill ${user.onboardingComplete ? 'complete' : ''}">${user.onboardingComplete ? 'Complete' : escapeHtml(user.onboardingStep || 'Incomplete')}</span></td>
      <td>${escapeHtml(joined)}</td>
      <td><button class="small-button" data-edit-user="${escapeHtml(user.id)}">Edit</button></td>
    </tr>`;
}

function openUserModal(user) {
  state.editingUserId = user.id;
  state.selectedUserPhotos = [];
  $('#user-photo-input').value = '';
  updatePhotoSelectionLabel(user);
  $('#user-modal-title').textContent = user.firstName
    ? `Edit ${user.firstName}`
    : 'Edit user';
  $('#user-first-name').value = user.firstName || '';
  $('#user-identity').value = user.identity || '';
  $('#user-country-code').value = user.countryCode || '';
  $('#user-phone-number').value = user.phoneNumber || '';
  $('#user-role').value = user.role || 'user';
  $('#user-account-status').value = user.accountStatus || 'active';
  $('#user-birth-date').value = toDateInput(user.birthDate);
  $('#user-height').value = user.heightCm ?? '';
  $('#user-bio').value = user.bio || '';
  $('#user-education').value = user.educationLevel || '';
  $('#user-looking-for').value = user.lookingFor || '';
  $('#user-children').value = user.children || '';
  $('#user-smoking').value = user.smoking || '';
  $('#user-interests').value = (user.happiness || []).join(', ');
  $('#user-location-label').value = user.location?.label || '';
  $('#user-latitude').value = user.location?.latitude ?? '';
  $('#user-longitude').value = user.location?.longitude ?? '';
  $('#user-onboarding-step').value = user.onboardingStep || '';
  $('#user-phone-verified').checked = user.isPhoneVerified === true;
  $('#user-onboarding-complete').checked = user.onboardingComplete === true;
  $('#user-show-star').checked = user.showStarOnProfile !== false;
  setChecked('#privacy-discoverable', user.privacySettings?.discoverable);
  setChecked('#privacy-online', user.privacySettings?.showOnlineStatus);
  setChecked('#privacy-distance', user.privacySettings?.showDistance);
  setChecked('#privacy-age', user.privacySettings?.showAge);
  setChecked('#notify-matches', user.notificationSettings?.newMatches);
  setChecked('#notify-messages', user.notificationSettings?.messages);
  setChecked('#notify-likes', user.notificationSettings?.likes);
  setChecked('#notify-calls', user.notificationSettings?.calls);
  $('#user-form-error').textContent = '';

  renderUserPhotos(user);
  const currentUserId = String(state.user?._id || state.user?.id || '');
  $('#delete-user-button').disabled = currentUserId === user.id;
  userModal.classList.remove('hidden');
  document.body.style.overflow = 'hidden';
}

function closeUserModal() {
  userModal.classList.add('hidden');
  state.editingUserId = null;
  state.selectedUserPhotos = [];
  $('#user-photo-input').value = '';
  document.body.style.overflow = '';
}

function renderUserPhotos(user) {
  const photos = user.photos || [];
  $('#user-photo-strip').innerHTML = photos.length
    ? photos
        .map(
          (photo, index) => `
            <article class="user-photo-card">
              <img src="${escapeHtml(photo.url)}" alt="User profile photo ${index + 1}">
              <div class="user-photo-actions">
                <button type="button" data-primary-photo="${index}" ${index === 0 ? 'disabled' : ''}>
                  ${index === 0 ? 'Primary' : 'Make primary'}
                </button>
                <button class="photo-remove" type="button" data-remove-photo="${index}" aria-label="Remove photo">&times;</button>
              </div>
            </article>`,
        )
        .join('')
    : '<div class="user-photo-empty">No profile photos uploaded</div>';
  updatePhotoSelectionLabel(user);
}

function updatePhotoSelectionLabel(user) {
  const currentCount = user?.photos?.length || 0;
  const selectedCount = state.selectedUserPhotos.length;
  const available = Math.max(0, 6 - currentCount);
  $('#photo-selection-label').textContent = selectedCount
    ? `${selectedCount} photo${selectedCount === 1 ? '' : 's'} selected · ${available} slot${available === 1 ? '' : 's'} available`
    : `${currentCount}/6 photos · up to 6 MB each`;
  $('#select-user-photos').disabled = available === 0;
  $('#upload-user-photos').disabled =
    selectedCount === 0 || selectedCount > available;
}

function applyUpdatedUser(user) {
  state.users = state.users.map((item) => (item.id === user.id ? user : item));
  userTableBody.innerHTML = state.users.map(userRow).join('');
  renderUserPhotos(user);
}

$('#select-user-photos').addEventListener('click', () =>
  $('#user-photo-input').click(),
);

$('#user-photo-input').addEventListener('change', (event) => {
  const user = state.users.find((item) => item.id === state.editingUserId);
  const available = Math.max(0, 6 - (user?.photos?.length || 0));
  state.selectedUserPhotos = [...event.target.files].slice(0, available);
  updatePhotoSelectionLabel(user);
});

$('#upload-user-photos').addEventListener('click', async () => {
  const userId = state.editingUserId;
  if (!userId || state.selectedUserPhotos.length === 0) return;
  const button = $('#upload-user-photos');
  const formData = new FormData();
  state.selectedUserPhotos.forEach((photo) => formData.append('photos', photo));
  $('#user-form-error').textContent = '';
  setBusy(button, true, 'Uploading...');
  try {
    const data = await apiForm(`/users/admin-users/${userId}/photos`, formData);
    state.selectedUserPhotos = [];
    $('#user-photo-input').value = '';
    applyUpdatedUser(data.user);
    showToast('Profile photos uploaded');
  } catch (error) {
    $('#user-form-error').textContent = error.message;
  } finally {
    setBusy(button, false, '');
    const user = state.users.find((item) => item.id === state.editingUserId);
    updatePhotoSelectionLabel(user);
  }
});

$('#user-photo-strip').addEventListener('click', async (event) => {
  const primaryIndex = event.target.dataset.primaryPhoto;
  const removeIndex = event.target.dataset.removePhoto;
  const userId = state.editingUserId;
  if (!userId || (primaryIndex == null && removeIndex == null)) return;
  const button = event.target;
  const isRemoving = removeIndex != null;
  if (
    isRemoving &&
    !window.confirm('Remove this profile photo permanently?')
  ) {
    return;
  }
  setBusy(button, true, isRemoving ? '...' : 'Saving...');
  $('#user-form-error').textContent = '';
  try {
    const path = isRemoving
      ? `/users/admin-users/${userId}/photos/${removeIndex}`
      : `/users/admin-users/${userId}/photos/${primaryIndex}/primary`;
    const data = await api(path, {
      method: isRemoving ? 'DELETE' : 'PATCH',
    });
    applyUpdatedUser(data.user);
    showToast(isRemoving ? 'Profile photo removed' : 'Primary photo updated');
  } catch (error) {
    $('#user-form-error').textContent = error.message;
  } finally {
    setBusy(button, false, '');
  }
});

$('#user-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const userId = state.editingUserId;
  if (!userId) return;
  const button = $('#save-user-button');
  const birthDate = $('#user-birth-date').value;
  const payload = {
    firstName: $('#user-first-name').value.trim() || null,
    identity: $('#user-identity').value || null,
    countryCode: $('#user-country-code').value.trim(),
    phoneNumber: $('#user-phone-number').value.trim(),
    role: $('#user-role').value,
    accountStatus: $('#user-account-status').value,
    birthDate: birthDate ? new Date(`${birthDate}T00:00:00`).toISOString() : null,
    heightCm: optionalNumber('#user-height'),
    bio: $('#user-bio').value.trim(),
    educationLevel: $('#user-education').value.trim(),
    lookingFor: $('#user-looking-for').value.trim(),
    children: $('#user-children').value.trim(),
    smoking: $('#user-smoking').value.trim(),
    happiness: $('#user-interests')
      .value.split(',')
      .map((item) => item.trim())
      .filter(Boolean)
      .slice(0, 12),
    location: {
      label: $('#user-location-label').value.trim() || null,
      latitude: optionalNumber('#user-latitude'),
      longitude: optionalNumber('#user-longitude'),
    },
    onboardingStep: $('#user-onboarding-step').value.trim(),
    isPhoneVerified: $('#user-phone-verified').checked,
    onboardingComplete: $('#user-onboarding-complete').checked,
    showStarOnProfile: $('#user-show-star').checked,
    privacySettings: {
      discoverable: $('#privacy-discoverable').checked,
      showOnlineStatus: $('#privacy-online').checked,
      showDistance: $('#privacy-distance').checked,
      showAge: $('#privacy-age').checked,
    },
    notificationSettings: {
      newMatches: $('#notify-matches').checked,
      messages: $('#notify-messages').checked,
      likes: $('#notify-likes').checked,
      calls: $('#notify-calls').checked,
    },
  };
  $('#user-form-error').textContent = '';
  setBusy(button, true, 'Saving...');
  try {
    await api(`/users/admin-users/${userId}`, {
      method: 'PATCH',
      body: JSON.stringify(payload),
    });
    closeUserModal();
    await loadUsers();
    showToast('User updated');
  } catch (error) {
    $('#user-form-error').textContent = error.message;
  } finally {
    setBusy(button, false, '');
  }
});

$('#delete-user-button').addEventListener('click', async () => {
  const userId = state.editingUserId;
  const user = state.users.find((item) => item.id === userId);
  if (!userId || !user) return;
  const confirmation = window.prompt(
    `Permanently delete ${user.firstName || user.phoneNumber}? Type DELETE to confirm.`,
  );
  if (confirmation !== 'DELETE') return;
  const button = $('#delete-user-button');
  setBusy(button, true, 'Deleting...');
  try {
    await api(`/users/admin-users/${userId}`, { method: 'DELETE' });
    closeUserModal();
    await loadUsers();
    showToast('User account deleted');
  } catch (error) {
    $('#user-form-error').textContent = error.message;
  } finally {
    setBusy(button, false, '');
  }
});

userTableBody.addEventListener('click', (event) => {
  const userId = event.target.dataset.editUser;
  if (!userId) return;
  const user = state.users.find((item) => item.id === userId);
  if (user) openUserModal(user);
});

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
document.querySelectorAll('[data-view]').forEach((button) => {
  button.addEventListener('click', () => setView(button.dataset.view));
});
document.querySelectorAll('[data-menu-button]').forEach((button) => {
  button.addEventListener('click', () => $('.sidebar').classList.toggle('open'));
});
$('#refresh-users-button').addEventListener('click', () => loadUsers());
$('#refresh-hosts-button').addEventListener('click', () =>
  loadHostApplications(),
);
$('#host-status-filter').addEventListener('change', () =>
  loadHostApplications(),
);
$('#host-request-grid').addEventListener('click', (event) => {
  const approveId = event.target.dataset.approveHost;
  const rejectId = event.target.dataset.rejectHost;
  if (approveId) reviewHostApplication(approveId, 'approved');
  if (rejectId) reviewHostApplication(rejectId, 'rejected');
});
$('#user-role-filter').addEventListener('change', () =>
  loadUsers({ resetPage: true }),
);
$('#user-status-filter').addEventListener('change', () =>
  loadUsers({ resetPage: true }),
);
let userSearchTimer;
$('#user-search').addEventListener('input', () => {
  clearTimeout(userSearchTimer);
  userSearchTimer = setTimeout(() => loadUsers({ resetPage: true }), 300);
});
$('#users-prev').addEventListener('click', () => {
  if (state.usersPage <= 1) return;
  state.usersPage -= 1;
  loadUsers();
});
$('#users-next').addEventListener('click', () => {
  if (!state.usersHasMore) return;
  state.usersPage += 1;
  loadUsers();
});
document
  .querySelectorAll('[data-close-modal]')
  .forEach((button) => button.addEventListener('click', closeModal));
document
  .querySelectorAll('[data-close-user-modal]')
  .forEach((button) => button.addEventListener('click', closeUserModal));
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') {
    closeModal();
    closeUserModal();
  }
});

if (state.token) {
  enterDashboard().catch((error) => showLogin(error.message));
} else {
  showLogin();
}
