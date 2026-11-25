/*
 * DesmoSTORM - MATLAB app for desmosomal plaque protein analysis.
 * Copyright (C) 2026 William Dean
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2 of the License, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, see <https://www.gnu.org/licenses/>.
 */

import java.io.File;
import java.nio.file.Path;
import java.nio.file.Paths;
import org.apache.pdfbox.Loader;
import org.apache.pdfbox.io.IOUtils;
import org.apache.pdfbox.multipdf.LayerUtility;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.PDPageContentStream;
import org.apache.pdfbox.pdmodel.common.PDRectangle;
import org.apache.pdfbox.pdmodel.graphics.form.PDFormXObject;
import org.apache.pdfbox.pdmodel.graphics.image.PDImageXObject;
import org.apache.pdfbox.util.Matrix;

/** Assembles exported DesmoSTORM pages with the bundled PDFBox library. */
public final class SummaryPDF {
    /**
     * Assemble the numbered layout, plot, and PNG files in the staging directory.
     * MATLAB passes the page size and both destination rectangles in PDF points.
     */
    public static void main(String[] args) throws Exception {
        // Directory containing the per-page exports and the assembled result.
        Path folder = Paths.get(args[0]);
        // Number of numbered input pages to assemble.
        int count = Integer.parseInt(args[1]);
        // Physical dimensions shared by every output page.
        float width = Float.parseFloat(args[2]);
        float height = Float.parseFloat(args[3]);

        // Destination rectangles for the plot and raster image layers.
        PDRectangle plot = new PDRectangle(Float.parseFloat(args[4]),
            Float.parseFloat(args[5]), Float.parseFloat(args[6]), Float.parseFloat(args[7]));

        PDRectangle image = new PDRectangle(Float.parseFloat(args[8]),
            Float.parseFloat(args[9]), Float.parseFloat(args[10]), Float.parseFloat(args[11]));

        // Use a disk-backed cache for large multipage exports.
        try (PDDocument document = new PDDocument(IOUtils.createTempFileOnlyStreamCache())) {
            LayerUtility layers = new LayerUtility(document);
            // Draw the layout first, then place the separately exported plot and image.
            for (int i = 1; i <= count; i++) {
                PDRectangle bounds = new PDRectangle(width, height);
                PDPage page = new PDPage(bounds);
                document.addPage(page);
                try (PDPageContentStream stream = new PDPageContentStream(document, page)) {
                    drawLayer(stream, layers, folder.resolve("layout-" + i + ".pdf").toFile(), bounds);
                    drawLayer(stream, layers, folder.resolve("plot-" + i + ".pdf").toFile(), plot);

                    // Embed the ImageAxes PNG at its original pixel resolution.
                    PDImageXObject region = PDImageXObject.createFromFileByExtension(
                        folder.resolve("image-" + i + ".png").toFile(), document);
                    region.setInterpolate(false);
                    stream.drawImage(region, image.getLowerLeftX(), image.getLowerLeftY(),
                        image.getWidth(), image.getHeight());
                }
            }
            document.save(folder.resolve("summary.pdf").toFile());
        }
    }

    /**
     * Place the first page of a source PDF in the destination rectangle,
     * preserving its PDF drawing commands.
     */
    private static void drawLayer(PDPageContentStream stream, LayerUtility layers,
                                  File file, PDRectangle destination) throws Exception {
        try (PDDocument source = Loader.loadPDF(file)) {
            // Import the source page as a form owned by the output document.
            PDFormXObject form = layers.importPageAsForm(source, 0);
            PDRectangle bounds = form.getBBox();
            // Map the source bounds onto the destination in both dimensions.
            float sx = destination.getWidth() / bounds.getWidth();
            float sy = destination.getHeight() / bounds.getHeight();

            // Keep the placement transform local to this layer.
            stream.saveGraphicsState();
            stream.transform(new Matrix(sx, 0, 0, sy,
                destination.getLowerLeftX() - sx * bounds.getLowerLeftX(),
                destination.getLowerLeftY() - sy * bounds.getLowerLeftY()));
            stream.drawForm(form);
            stream.restoreGraphicsState();
        }
    }
}
