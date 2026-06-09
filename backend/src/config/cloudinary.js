import { v2 as cloudinary } from 'cloudinary';

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

export function assertCloudinaryConfigured() {
  const missing = [
    ['CLOUDINARY_CLOUD_NAME', process.env.CLOUDINARY_CLOUD_NAME],
    ['CLOUDINARY_API_KEY', process.env.CLOUDINARY_API_KEY],
    ['CLOUDINARY_API_SECRET', process.env.CLOUDINARY_API_SECRET],
  ]
    .filter(([, value]) => !value)
    .map(([key]) => key);

  if (missing.length > 0) {
    const error = new Error(
      `Cloudinary config missing: ${missing.join(', ')}. Add it to backend/.env.`,
    );
    error.status = 500;
    throw error;
  }
}

export function uploadBufferToCloudinary(buffer, options) {
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(options, (error, result) => {
      if (error) return reject(error);
      return resolve(result);
    });
    stream.end(buffer);
  });
}

export function deleteCloudinaryAsset(publicId, resourceType = 'image') {
  if (!publicId) return Promise.resolve();
  assertCloudinaryConfigured();
  return cloudinary.uploader.destroy(publicId, {
    resource_type: resourceType,
    invalidate: true,
  });
}

export { cloudinary };
