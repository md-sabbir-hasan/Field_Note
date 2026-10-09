package com.fieldnotes.backend.storage;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.UUID;

/** Stores note photos on local disk. Only server generated file names ever touch the file system. */
@Component
public class PhotoStorage {

    private static final byte[] PNG_SIGNATURE = {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A};

    private final Path root;

    public PhotoStorage(@Value("${app.upload.dir}") String uploadDir) {
        this.root = Path.of(uploadDir).toAbsolutePath().normalize();
        try {
            Files.createDirectories(root);
        } catch (IOException e) {
            throw new IllegalStateException("Cannot create upload directory: " + root, e);
        }
    }

    /** Validates the image, saves it under a random name and returns that name. */
    public String store(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Photo file is empty");
        }

        String filename = UUID.randomUUID() + detectExtension(file);

        try (InputStream in = file.getInputStream()) {
            Files.copy(in, root.resolve(filename));
        } catch (IOException e) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Could not save photo");
        }
        return filename;
    }

    public Resource load(String filename) {
        Path path = resolve(filename);
        if (!Files.isReadable(path)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Photo not found");
        }
        return new FileSystemResource(path);
    }

    /** Best effort cleanup: a leftover file must never break the request. */
    public void deleteQuietly(String filename) {
        if (filename == null) return;
        try {
            Files.deleteIfExists(resolve(filename));
        } catch (IOException | ResponseStatusException ignored) {
            // nothing useful to do, the file is just an orphan
        }
    }

    public static MediaType mediaTypeOf(String filename) {
        String name = filename == null ? "" : filename.toLowerCase();
        if (name.endsWith(".png")) return MediaType.IMAGE_PNG;
        if (name.endsWith(".webp")) return MediaType.parseMediaType("image/webp");
        return MediaType.IMAGE_JPEG;
    }

    // Defence in depth: even a bad name from the DB cannot escape the upload directory.
    private Path resolve(String filename) {
        Path path = root.resolve(filename).normalize();
        if (!path.startsWith(root)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid file name");
        }
        return path;
    }

    // Decides the type from the real file bytes, not from the client supplied Content-Type.
    private String detectExtension(MultipartFile file) {
        byte[] head = new byte[12];
        int read;
        try (InputStream in = file.getInputStream()) {
            read = in.readNBytes(head, 0, head.length);
        } catch (IOException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Could not read photo");
        }

        boolean jpeg = read >= 3
                && head[0] == (byte) 0xFF && head[1] == (byte) 0xD8 && head[2] == (byte) 0xFF;

        boolean png = read >= 8;
        for (int i = 0; png && i < PNG_SIGNATURE.length; i++) {
            png = head[i] == PNG_SIGNATURE[i];
        }

        // WebP: "RIFF" + 4 size bytes + "WEBP"
        boolean webp = read >= 12
                && head[0] == 'R' && head[1] == 'I' && head[2] == 'F' && head[3] == 'F'
                && head[8] == 'W' && head[9] == 'E' && head[10] == 'B' && head[11] == 'P';

        if (jpeg) return ".jpg";
        if (png) return ".png";
        if (webp) return ".webp";
        throw new ResponseStatusException(HttpStatus.UNSUPPORTED_MEDIA_TYPE,
                "Only JPEG, PNG or WebP images are allowed");
    }
}