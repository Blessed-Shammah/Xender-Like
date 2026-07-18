const express = require('express');
const multer = require('multer');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');
const mime = require('mime-types');

const app = express();
const PORT = process.env.PORT || 3009;

// --- Directory Setup ---
const UPLOADS_DIR = path.join(__dirname, 'uploads');
const DATA_DIR = path.join(__dirname, 'data');
const DB_FILE = path.join(DATA_DIR, 'files.json');

if (!fs.existsSync(UPLOADS_DIR)) fs.mkdirSync(UPLOADS_DIR, { recursive: true });
if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
if (!fs.existsSync(DB_FILE)) fs.writeFileSync(DB_FILE, '[]');

// --- Middleware ---
app.use(cors());
app.use(express.json());

// --- Serve built webapp in production ---
const PUBLIC_DIR = path.join(__dirname, 'public');
if (fs.existsSync(PUBLIC_DIR)) {
    app.use(express.static(PUBLIC_DIR));
}

// --- Helpers ---
function readDB() {
    try {
        return JSON.parse(fs.readFileSync(DB_FILE, 'utf-8'));
    } catch {
        return [];
    }
}

function writeDB(data) {
    fs.writeFileSync(DB_FILE, JSON.stringify(data, null, 2));
}

function formatBytes(bytes) {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function getFileCategory(mimeType) {
    if (!mimeType) return 'other';
    if (mimeType.startsWith('image/')) return 'image';
    if (mimeType.startsWith('video/')) return 'video';
    if (mimeType.startsWith('audio/')) return 'audio';
    if (mimeType.startsWith('text/')) return 'document';
    if (mimeType.includes('pdf')) return 'document';
    if (mimeType.includes('word') || mimeType.includes('document')) return 'document';
    if (mimeType.includes('sheet') || mimeType.includes('excel')) return 'spreadsheet';
    if (mimeType.includes('presentation') || mimeType.includes('powerpoint')) return 'presentation';
    if (mimeType.includes('zip') || mimeType.includes('rar') || mimeType.includes('tar') || mimeType.includes('compress')) return 'archive';
    return 'other';
}

// --- Multer Config ---
const storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, UPLOADS_DIR),
    filename: (req, file, cb) => {
        const id = uuidv4();
        const ext = path.extname(file.originalname);
        cb(null, `${id}${ext}`);
    }
});

const upload = multer({
    storage,
    limits: { fileSize: 20 * 1024 * 1024 * 1024 } // 20GB limit
});

// ========================================
// API ROUTES
// ========================================

// --- Upload files ---
app.post('/api/upload', upload.array('files', 20), (req, res) => {
    try {
        if (!req.files || req.files.length === 0) {
            return res.status(400).json({ error: 'No files uploaded' });
        }

        const db = readDB();
        const uploadedFiles = [];

        for (const file of req.files) {
            const mimeType = mime.lookup(file.originalname) || file.mimetype;
            const fileRecord = {
                id: path.parse(file.filename).name,
                originalName: file.originalname,
                storedName: file.filename,
                size: file.size,
                sizeFormatted: formatBytes(file.size),
                mimeType,
                category: getFileCategory(mimeType),
                extension: path.extname(file.originalname).replace('.', '').toLowerCase(),
                uploadedAt: new Date().toISOString()
            };

            db.push(fileRecord);
            uploadedFiles.push(fileRecord);
        }

        writeDB(db);
        res.status(201).json({
            message: `${uploadedFiles.length} file(s) uploaded successfully`,
            files: uploadedFiles
        });
    } catch (err) {
        console.error('Upload error:', err);
        res.status(500).json({ error: 'Upload failed' });
    }
});

// --- List all files ---
app.get('/api/files', (req, res) => {
    try {
        const db = readDB();
        const { search, category, sort } = req.query;

        let files = [...db];

        // Search filter
        if (search) {
            const q = search.toLowerCase();
            files = files.filter(f => f.originalName.toLowerCase().includes(q));
        }

        // Category filter
        if (category && category !== 'all') {
            files = files.filter(f => f.category === category);
        }

        // Sort
        if (sort === 'name') {
            files.sort((a, b) => a.originalName.localeCompare(b.originalName));
        } else if (sort === 'size') {
            files.sort((a, b) => b.size - a.size);
        } else {
            // Default: newest first
            files.sort((a, b) => new Date(b.uploadedAt) - new Date(a.uploadedAt));
        }

        res.json({
            total: files.length,
            files
        });
    } catch (err) {
        console.error('List error:', err);
        res.status(500).json({ error: 'Could not list files' });
    }
});

// --- Get file info ---
app.get('/api/files/:id', (req, res) => {
    const db = readDB();
    const file = db.find(f => f.id === req.params.id);
    if (!file) return res.status(404).json({ error: 'File not found' });
    res.json(file);
});

// --- Download file ---
app.get('/api/files/:id/download', (req, res) => {
    const db = readDB();
    const file = db.find(f => f.id === req.params.id);
    if (!file) return res.status(404).json({ error: 'File not found' });

    const filePath = path.join(UPLOADS_DIR, file.storedName);
    if (!fs.existsSync(filePath)) {
        return res.status(404).json({ error: 'File not found on disk' });
    }

    res.download(filePath, file.originalName);
});

// --- Preview file (inline) ---
app.get('/api/files/:id/preview', (req, res) => {
    const db = readDB();
    const file = db.find(f => f.id === req.params.id);
    if (!file) return res.status(404).json({ error: 'File not found' });

    const filePath = path.join(UPLOADS_DIR, file.storedName);
    if (!fs.existsSync(filePath)) {
        return res.status(404).json({ error: 'File not found on disk' });
    }

    res.setHeader('Content-Type', file.mimeType);
    res.setHeader('Content-Disposition', `inline; filename="${file.originalName}"`);
    fs.createReadStream(filePath).pipe(res);
});

// --- Delete file ---
app.delete('/api/files/:id', (req, res) => {
    try {
        let db = readDB();
        const fileIndex = db.findIndex(f => f.id === req.params.id);
        if (fileIndex === -1) return res.status(404).json({ error: 'File not found' });

        const file = db[fileIndex];
        const filePath = path.join(UPLOADS_DIR, file.storedName);

        // Delete from disk
        if (fs.existsSync(filePath)) {
            fs.unlinkSync(filePath);
        }

        // Delete from DB
        db.splice(fileIndex, 1);
        writeDB(db);

        res.json({ message: 'File deleted successfully', id: req.params.id });
    } catch (err) {
        console.error('Delete error:', err);
        res.status(500).json({ error: 'Delete failed' });
    }
});

// --- Server stats ---
app.get('/api/stats', (req, res) => {
    const db = readDB();
    const totalSize = db.reduce((sum, f) => sum + f.size, 0);
    const categories = {};
    db.forEach(f => {
        categories[f.category] = (categories[f.category] || 0) + 1;
    });

    res.json({
        totalFiles: db.length,
        totalSize,
        totalSizeFormatted: formatBytes(totalSize),
        categories
    });
});

// --- Start Server ---
app.listen(PORT, '0.0.0.0', () => {
    console.log(`\n  🗄️  FileVault Server running on:`);
    console.log(`     Local:   http://localhost:${PORT}`);

    // Show network IP for mobile access
    const { networkInterfaces } = require('os');
    const nets = networkInterfaces();
    for (const name of Object.keys(nets)) {
        for (const net of nets[name]) {
            if (net.family === 'IPv4' && !net.internal) {
                console.log(`     Network: http://${net.address}:${PORT}`);
            }
        }
    }
    console.log('');
});
