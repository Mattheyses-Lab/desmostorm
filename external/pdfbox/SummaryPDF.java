// DesmoSTORM summary PDF assembler. Compile against the bundled PDFBox JAR.
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

public final class SummaryPDF {
    public static void main(String[] args) throws Exception {
        Path folder = Paths.get(args[0]);
        int count = Integer.parseInt(args[1]);
        float width = Float.parseFloat(args[2]);
        float height = Float.parseFloat(args[3]);
        PDRectangle plot = new PDRectangle(Float.parseFloat(args[4]),
            Float.parseFloat(args[5]), Float.parseFloat(args[6]), Float.parseFloat(args[7]));

        PDRectangle image = new PDRectangle(Float.parseFloat(args[8]),
            Float.parseFloat(args[9]), Float.parseFloat(args[10]), Float.parseFloat(args[11]));

        try (PDDocument document = new PDDocument(IOUtils.createTempFileOnlyStreamCache())) {
            LayerUtility layers = new LayerUtility(document);
            for (int i = 1; i <= count; i++) {
                PDRectangle bounds = new PDRectangle(width, height);
                PDPage page = new PDPage(bounds);
                document.addPage(page);
                try (PDPageContentStream stream = new PDPageContentStream(document, page)) {
                    drawLayer(stream, layers, folder.resolve("layout-" + i + ".pdf").toFile(), bounds);
                    drawLayer(stream, layers, folder.resolve("plot-" + i + ".pdf").toFile(), plot);
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

    private static void drawLayer(PDPageContentStream stream, LayerUtility layers,
                                  File file, PDRectangle destination) throws Exception {
        try (PDDocument source = Loader.loadPDF(file)) {
            PDFormXObject form = layers.importPageAsForm(source, 0);
            PDRectangle bounds = form.getBBox();
            float sx = destination.getWidth() / bounds.getWidth();
            float sy = destination.getHeight() / bounds.getHeight();
            stream.saveGraphicsState();
            stream.transform(new Matrix(sx, 0, 0, sy,
                destination.getLowerLeftX() - sx * bounds.getLowerLeftX(),
                destination.getLowerLeftY() - sy * bounds.getLowerLeftY()));
            stream.drawForm(form);
            stream.restoreGraphicsState();
        }
    }
}
