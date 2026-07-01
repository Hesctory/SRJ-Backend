using MigraDoc.DocumentObjectModel;
using MigraDoc.DocumentObjectModel.Tables;
using MigraDoc.Rendering;

namespace SRJBackend.Infrastructure.Reports;

/// <summary>
/// Renders a <see cref="TableReportModel"/> to a PDF that mirrors the previous
/// React-PDF tabular layout: centered header band (school / title / filter context),
/// a dark header row with zebra-striped data rows, and a footer with the total and
/// "Página X de Y".
/// </summary>
public sealed class TablePdfRenderer
{
    private static readonly Color HeaderBand = new(0x1A, 0x1A, 0x2E);
    private static readonly Color ZebraRow = new(0xF5, 0xF5, 0xF5);
    private static readonly Color RuleColor = new(0x33, 0x33, 0x33);
    private static readonly Color SubtitleColor = new(0x55, 0x55, 0x55);

    public byte[] Render(TableReportModel model)
    {
        var document = new Document();
        var normal = document.Styles["Normal"]!;
        normal.Font.Name = "Liberation Sans";
        normal.Font.Size = 9;

        var section = document.AddSection();
        var setup = section.PageSetup;
        setup.PageFormat = PageFormat.A4;
        setup.TopMargin = Unit.FromCentimeter(1.5);
        setup.BottomMargin = Unit.FromCentimeter(1.5);
        setup.LeftMargin = Unit.FromCentimeter(1.5);
        setup.RightMargin = Unit.FromCentimeter(1.5);

        AddHeaderBand(section, model);
        AddTable(section, model);
        AddFooter(section, model);

        return RenderToBytes(document);
    }

    private static void AddHeaderBand(Section section, TableReportModel model)
    {
        var school = section.AddParagraph(model.SchoolName);
        school.Format.Alignment = ParagraphAlignment.Center;
        school.Format.Font.Size = 16;
        school.Format.Font.Bold = true;
        school.Format.SpaceAfter = Unit.FromPoint(4);

        var title = section.AddParagraph(model.Title);
        title.Format.Alignment = ParagraphAlignment.Center;
        title.Format.Font.Size = 12;
        title.Format.Font.Bold = true;
        title.Format.SpaceAfter = Unit.FromPoint(4);

        var context = section.AddParagraph(model.ContextLine);
        context.Format.Alignment = ParagraphAlignment.Center;
        context.Format.Font.Size = 9;
        context.Format.Font.Color = SubtitleColor;
        context.Format.SpaceAfter = Unit.FromPoint(10);
        context.Format.Borders.Bottom.Width = 1.5;
        context.Format.Borders.Bottom.Color = RuleColor;
    }

    private static void AddTable(Section section, TableReportModel model)
    {
        // Padding matches the previous React-PDF layout (rows paddingVertical 5,
        // paddingHorizontal 4) so the vertical rhythm lines up.
        var table = section.AddTable();
        table.TopPadding = Unit.FromPoint(5);
        table.BottomPadding = Unit.FromPoint(5);
        table.LeftPadding = Unit.FromPoint(4);
        table.RightPadding = Unit.FromPoint(4);

        foreach (var col in model.Columns)
            table.AddColumn(Unit.FromCentimeter(col.WidthCm));

        // Header row.
        var header = table.AddRow();
        header.Shading.Color = HeaderBand;
        header.Format.Font.Bold = true;
        header.Format.Font.Color = Colors.White;
        header.HeadingFormat = true; // repeat on every page
        for (var i = 0; i < model.Columns.Count; i++)
            header.Cells[i].AddParagraph(model.Columns[i].Header);

        // Data rows with zebra striping.
        for (var r = 0; r < model.Rows.Count; r++)
        {
            var row = table.AddRow();
            if (r % 2 == 1)
                row.Shading.Color = ZebraRow;

            var cells = model.Rows[r];
            for (var c = 0; c < model.Columns.Count; c++)
                row.Cells[c].AddParagraph(c < cells.Count ? cells[c] ?? string.Empty : string.Empty);
        }
    }

    private static void AddFooter(Section section, TableReportModel model)
    {
        var footer = section.Footers.Primary.AddParagraph();
        footer.Format.Font.Size = 8;
        footer.Format.Font.Color = new Color(0x88, 0x88, 0x88);
        footer.Format.AddTabStop(section.PageSetup.PageWidth - section.PageSetup.LeftMargin - section.PageSetup.RightMargin,
            TabAlignment.Right);
        footer.AddText($"Total: {model.Total} estudiante(s)");
        footer.AddTab();
        footer.AddText("Página ");
        footer.AddPageField();
        footer.AddText(" de ");
        footer.AddNumPagesField();
    }

    private static byte[] RenderToBytes(Document document)
    {
        var renderer = new PdfDocumentRenderer { Document = document };
        renderer.RenderDocument();
        using var stream = new MemoryStream();
        renderer.PdfDocument.Save(stream);
        return stream.ToArray();
    }
}
