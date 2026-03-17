// ========================================
// FileVault — Main Application Logic
// ========================================

const API_BASE = '/api';

// --- DOM Elements ---
const uploadZone = document.getElementById('upload-zone');
const fileInput = document.getElementById('file-input');
const browseBtn = document.getElementById('browse-btn');
const uploadProgress = document.getElementById('upload-progress');
const progressFill = document.getElementById('progress-fill');
const progressText = document.getElementById('progress-text');

const filesGrid = document.getElementById('files-grid');
const emptyState = document.getElementById('empty-state');
const fileCount = document.getElementById('file-count');

const searchInput = document.getElementById('search-input');
const categoryFilter = document.getElementById('category-filter');
const sortSelect = document.getElementById('sort-select');
const gridViewBtn = document.getElementById('grid-view-btn');
const listViewBtn = document.getElementById('list-view-btn');

const deleteModal = document.getElementById('delete-modal');
const deleteFileName = document.getElementById('delete-file-name');
const cancelDeleteBtn = document.getElementById('cancel-delete-btn');
const confirmDeleteBtn = document.getElementById('confirm-delete-btn');

const statTotalFiles = document.getElementById('stat-total-files');
const statTotalSize = document.getElementById('stat-total-size');

const toastContainer = document.getElementById('toast-container');

let pendingDeleteId = null;
let currentView = 'grid';

// ========================================
// Toast Notifications
// ========================================
function showToast(message, type = 'success') {
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    const icon = type === 'success' ? 'check_circle' : 'error';
    toast.innerHTML = `
    <span class="material-icons-round">${icon}</span>
    <span>${message}</span>
  `;
    toastContainer.appendChild(toast);
    setTimeout(() => {
        toast.classList.add('toast-out');
        setTimeout(() => toast.remove(), 300);
    }, 3500);
}

// ========================================
// File Category Icons
// ========================================
function getCategoryIcon(category) {
    const icons = {
        image: 'image',
        video: 'videocam',
        audio: 'headphones',
        document: 'description',
        spreadsheet: 'table_chart',
        presentation: 'slideshow',
        archive: 'folder_zip',
        other: 'insert_drive_file'
    };
    return icons[category] || 'insert_drive_file';
}

// ========================================
// Format Date
// ========================================
function formatDate(dateString) {
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays < 7) return `${diffDays}d ago`;
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

// ========================================
// Render File Card
// ========================================
function createFileCard(file, index) {
    const card = document.createElement('div');
    card.className = 'file-card';
    card.style.animationDelay = `${index * 50}ms`;

    // Preview section
    let previewHTML;
    if (file.category === 'image') {
        previewHTML = `<img src="${API_BASE}/files/${file.id}/preview" alt="${file.originalName}" loading="lazy" />`;
    } else {
        previewHTML = `
      <div class="file-type-icon category-${file.category}">
        <span class="material-icons-round">${getCategoryIcon(file.category)}</span>
        <span class="file-type-badge">${file.extension || '?'}</span>
      </div>
    `;
    }

    card.innerHTML = `
    <div class="file-card-preview">
      ${previewHTML}
    </div>
    <div class="file-card-body">
      <div class="file-card-name" title="${file.originalName}">${file.originalName}</div>
      <div class="file-card-meta">
        <span>${file.sizeFormatted} · ${formatDate(file.uploadedAt)}</span>
        <div class="file-card-actions">
          <button class="btn-icon download-btn" title="Download" data-id="${file.id}">
            <span class="material-icons-round">download</span>
          </button>
          <button class="btn-icon delete-btn" title="Delete" data-id="${file.id}" data-name="${file.originalName}">
            <span class="material-icons-round">delete</span>
          </button>
        </div>
      </div>
    </div>
  `;

    // Event listeners
    card.querySelector('.download-btn').addEventListener('click', (e) => {
        e.stopPropagation();
        downloadFile(file.id, file.originalName);
    });

    card.querySelector('.delete-btn').addEventListener('click', (e) => {
        e.stopPropagation();
        openDeleteModal(file.id, file.originalName);
    });

    return card;
}

// ========================================
// Load & Render Files
// ========================================
async function loadFiles() {
    try {
        const params = new URLSearchParams();
        const search = searchInput.value.trim();
        const category = categoryFilter.value;
        const sort = sortSelect.value;

        if (search) params.set('search', search);
        if (category !== 'all') params.set('category', category);
        if (sort) params.set('sort', sort);

        const res = await fetch(`${API_BASE}/files?${params}`);
        const data = await res.json();

        filesGrid.innerHTML = '';

        if (data.files.length === 0) {
            emptyState.hidden = false;
            filesGrid.style.display = 'none';
            fileCount.textContent = '';
        } else {
            emptyState.hidden = true;
            filesGrid.style.display = '';
            fileCount.textContent = `(${data.total})`;
            data.files.forEach((file, i) => {
                filesGrid.appendChild(createFileCard(file, i));
            });
        }

        // Update stats
        loadStats();
    } catch (err) {
        console.error('Failed to load files:', err);
        showToast('Failed to load files', 'error');
    }
}

async function loadStats() {
    try {
        const res = await fetch(`${API_BASE}/stats`);
        const data = await res.json();
        statTotalFiles.textContent = `${data.totalFiles} file${data.totalFiles !== 1 ? 's' : ''}`;
        statTotalSize.textContent = data.totalSizeFormatted;
    } catch (err) {
        console.error('Failed to load stats:', err);
    }
}

// ========================================
// Upload Files
// ========================================
async function uploadFiles(files) {
    if (!files || files.length === 0) return;

    const formData = new FormData();
    for (const file of files) {
        formData.append('files', file);
    }

    // Show progress
    uploadProgress.hidden = false;
    progressFill.style.width = '0%';
    progressText.textContent = `Uploading ${files.length} file(s)...`;

    try {
        const xhr = new XMLHttpRequest();

        xhr.upload.addEventListener('progress', (e) => {
            if (e.lengthComputable) {
                const percent = Math.round((e.loaded / e.total) * 100);
                progressFill.style.width = `${percent}%`;
                progressText.textContent = `Uploading... ${percent}%`;
            }
        });

        await new Promise((resolve, reject) => {
            xhr.addEventListener('load', () => {
                if (xhr.status >= 200 && xhr.status < 300) {
                    resolve(JSON.parse(xhr.responseText));
                } else {
                    reject(new Error('Upload failed'));
                }
            });
            xhr.addEventListener('error', reject);
            xhr.open('POST', `${API_BASE}/upload`);
            xhr.send(formData);
        });

        progressText.textContent = 'Upload complete!';
        progressFill.style.width = '100%';
        showToast(`${files.length} file(s) uploaded successfully`);

        setTimeout(() => {
            uploadProgress.hidden = true;
            progressFill.style.width = '0%';
        }, 1500);

        loadFiles();
    } catch (err) {
        console.error('Upload error:', err);
        progressText.textContent = 'Upload failed';
        showToast('Upload failed', 'error');
        setTimeout(() => { uploadProgress.hidden = true; }, 2000);
    }
}

// ========================================
// Download File
// ========================================
function downloadFile(id, name) {
    const a = document.createElement('a');
    a.href = `${API_BASE}/files/${id}/download`;
    a.download = name;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    showToast(`Downloading ${name}`);
}

// ========================================
// Delete File
// ========================================
function openDeleteModal(id, name) {
    pendingDeleteId = id;
    deleteFileName.textContent = `"${name}" will be permanently deleted.`;
    deleteModal.hidden = false;
}

function closeDeleteModal() {
    deleteModal.hidden = true;
    pendingDeleteId = null;
}

async function confirmDelete() {
    if (!pendingDeleteId) return;

    try {
        const res = await fetch(`${API_BASE}/files/${pendingDeleteId}`, { method: 'DELETE' });
        if (res.ok) {
            showToast('File deleted');
            loadFiles();
        } else {
            showToast('Delete failed', 'error');
        }
    } catch (err) {
        console.error('Delete error:', err);
        showToast('Delete failed', 'error');
    }

    closeDeleteModal();
}

// ========================================
// View Toggle
// ========================================
function setView(view) {
    currentView = view;
    if (view === 'list') {
        filesGrid.classList.add('list-view');
        listViewBtn.classList.add('active');
        gridViewBtn.classList.remove('active');
    } else {
        filesGrid.classList.remove('list-view');
        gridViewBtn.classList.add('active');
        listViewBtn.classList.remove('active');
    }
}

// ========================================
// Event Listeners
// ========================================

// --- Drag & Drop ---
uploadZone.addEventListener('dragover', (e) => {
    e.preventDefault();
    uploadZone.classList.add('drag-over');
});

uploadZone.addEventListener('dragleave', (e) => {
    e.preventDefault();
    uploadZone.classList.remove('drag-over');
});

uploadZone.addEventListener('drop', (e) => {
    e.preventDefault();
    uploadZone.classList.remove('drag-over');
    uploadFiles(e.dataTransfer.files);
});

// --- Click to browse ---
uploadZone.addEventListener('click', (e) => {
    if (e.target !== browseBtn && !browseBtn.contains(e.target)) {
        fileInput.click();
    }
});

browseBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    fileInput.click();
});

fileInput.addEventListener('change', () => {
    if (fileInput.files.length > 0) {
        uploadFiles(fileInput.files);
        fileInput.value = '';
    }
});

// --- Search & Filters ---
let searchTimeout;
searchInput.addEventListener('input', () => {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(loadFiles, 300);
});

categoryFilter.addEventListener('change', loadFiles);
sortSelect.addEventListener('change', loadFiles);

// --- View toggle ---
gridViewBtn.addEventListener('click', () => setView('grid'));
listViewBtn.addEventListener('click', () => setView('list'));

// --- Delete modal ---
cancelDeleteBtn.addEventListener('click', closeDeleteModal);
confirmDeleteBtn.addEventListener('click', confirmDelete);
deleteModal.addEventListener('click', (e) => {
    if (e.target === deleteModal) closeDeleteModal();
});

// --- Keyboard shortcuts ---
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeDeleteModal();
});

// ========================================
// Init
// ========================================
loadFiles();
