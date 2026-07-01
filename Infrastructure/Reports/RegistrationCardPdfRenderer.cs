using MigraDoc.DocumentObjectModel;
using MigraDoc.DocumentObjectModel.Tables;
using MigraDoc.Rendering;
using SRJBackend.Application.DTOs;

namespace SRJBackend.Infrastructure.Reports;

/// <summary>
/// Renders the registration cards ("Ficha de Matrícula") to PDF — one A4 page per
/// student — mirroring the previous React-PDF document (sections I–V, the fixed
/// required-documents checklist, an observation box and two signature lines).
/// </summary>
public sealed class RegistrationCardPdfRenderer
{
    private static readonly Color HeaderBg = new(0xE8, 0xE8, 0xE8);
    private static readonly Color BorderColor = new(0x99, 0x99, 0x99);
    private const double BorderWidth = 0.5;
    private const double UsableWidthCm = 18.0;

    private static readonly string[] RequiredDocs =
    {
        "Ficha de Matrícula",
        "Certificado de Estudios",
        "Certificado de Conducta",
        "Copia DNI Alumno",
        "Copia DNI Apoderado",
        "Partida de Nacimiento",
        "Libreta de Notas",
        "Resolución de Traslado",
        "Fotos",
    };

    public byte[] Render(IReadOnlyList<RegistrationCardDTO> students, DateTime generatedAt)
    {
        var document = new Document();
        var normal = document.Styles["Normal"]!;
        normal.Font.Name = "Liberation Sans";
        normal.Font.Size = 8.5;

        var generatedDate = generatedAt.ToString("dd/MM/yyyy");
        var generatedTime = generatedAt.ToString("HH:mm");

        for (var i = 0; i < students.Count; i++)
        {
            var section = document.AddSection();
            var setup = section.PageSetup;
            setup.PageFormat = PageFormat.A4;
            setup.TopMargin = Unit.FromCentimeter(1.2);
            setup.BottomMargin = Unit.FromCentimeter(1.2);
            setup.LeftMargin = Unit.FromCentimeter(1.5);
            setup.RightMargin = Unit.FromCentimeter(1.5);

            RenderCard(section, students[i], generatedDate, generatedTime);
        }

        var renderer = new PdfDocumentRenderer { Document = document };
        renderer.RenderDocument();
        using var stream = new MemoryStream();
        renderer.PdfDocument.Save(stream);
        return stream.ToArray();
    }

    private static void RenderCard(Section section, RegistrationCardDTO s, string date, string time)
    {
        var title = section.AddParagraph("FICHA DE MATRÍCULA");
        title.Format.Alignment = ParagraphAlignment.Center;
        title.Format.Font.Size = 14;
        title.Format.Font.Bold = true;
        title.Format.SpaceAfter = Unit.FromPoint(8);

        // Top info bands.
        AddInfoBand(section, ($"Fecha: {date}", $"Hora: {time}", $"Año: {s.schoolYear}"));
        AddInfoBand(section, ($"Grado: {s.grade}", $"Nivel: {s.level}", $"Sección: {s.section}", $"Código: {s.enrollmentCode}"));

        // I. Student.
        AddSectionTitle(section, "I. Datos Alumno/a");
        var student = NewTable(section, 6);
        AddRow(student, ("Apellido Paterno", true), (s.paternalLastName, false),
                        ("Apellido Materno", true), (s.maternalLastName, false),
                        ("Nombres", true), (s.firstName, false));
        AddRow(student, ("Fecha Nac.", true), (FormatDate(s.birthDate), false),
                        ("Lugar Nac.", true), (s.birthPlace, false),
                        ("País", true), (s.birthCountry, false));
        AddRow(student, ("Sexo", true), (s.gender, false),
                        ("Religión", true), (s.religion, false),
                        ("DNI", true), (s.dni, false));
        AddRow(student, ("N° Hermanos", true), (s.siblings?.ToString(), false),
                        ("Lugar que ocupa", true), (s.siblingPosition?.ToString(), false),
                        ("Discapacidad", true), (s.disability, false));
        AddSpannedRow(student, ("Colegio Procedencia", 1, true), (s.previousSchool, 5, false));
        AddSpannedRow(student, ("Dirección", 1, true), (s.address, 3, false),
                               ("Distrito", 1, true), (s.district, 1, false));

        // II. Mother / III. Father.
        AddSectionTitle(section, "II. Datos de la Madre");
        AddParentTable(section, s.mother);
        AddSectionTitle(section, "III. Datos del Padre");
        AddParentTable(section, s.father);

        // IV. Guardian.
        var g = s.guardian;
        AddSectionTitle(section, $"IV. Datos del Apoderado – Tipo Parentesco: {g?.relationship}");
        var guardian = NewTable(section, 6);
        AddSpannedRow(guardian, ("Apellidos", 1, true), (JoinNames(g?.paternalLastName, g?.maternalLastName), 3, false),
                                ("Nombres", 1, true), (g?.firstName, 1, false));
        AddRow(guardian, ("DNI", true), (g?.dni, false),
                         ("Celular", true), (g?.phone, false),
                         ("Email", true), (g?.email, false));

        // V. Fees + required documents checklist, side by side (as in the original layout).
        AddSectionTitle(section, "V. Cuadro de Pagos / Documentos Requeridos");
        AddFeesAndDocs(section, s.fees);

        AddObservationBox(section);
        AddSignatures(section);
    }

    // --- Layout helpers ---

    private static Table NewTable(Section section, int columns)
    {
        var table = section.AddTable();
        table.Borders.Width = BorderWidth;
        table.Borders.Color = BorderColor;
        table.TopPadding = Unit.FromPoint(3);
        table.BottomPadding = Unit.FromPoint(3);
        table.LeftPadding = Unit.FromPoint(3);
        table.RightPadding = Unit.FromPoint(3);

        var width = Unit.FromCentimeter(UsableWidthCm / columns);
        for (var i = 0; i < columns; i++)
            table.AddColumn(width);
        return table;
    }

    private static void AddRow(Table table, params (string? Text, bool Header)[] cells)
    {
        var row = table.AddRow();
        for (var i = 0; i < cells.Length; i++)
            Fill(row.Cells[i], cells[i].Text, cells[i].Header);
    }

    private static void AddSpannedRow(Table table, params (string? Text, int Span, bool Header)[] cells)
    {
        var row = table.AddRow();
        var col = 0;
        foreach (var (text, span, header) in cells)
        {
            var cell = row.Cells[col];
            if (span > 1) cell.MergeRight = span - 1;
            Fill(cell, text, header);
            col += span;
        }
    }

    private static void Fill(Cell cell, string? text, bool header)
    {
        if (header)
        {
            cell.Shading.Color = HeaderBg;
            cell.Format.Font.Bold = true;
        }
        cell.AddParagraph(text ?? string.Empty);
    }

    private static void AddInfoBand(Section section, params string[] cellsTuple)
    {
        // params expansion of a value tuple isn't possible; overloads below pass arrays.
        var table = NewTable(section, cellsTuple.Length);
        var row = table.AddRow();
        for (var i = 0; i < cellsTuple.Length; i++)
            row.Cells[i].AddParagraph(cellsTuple[i]);
    }

    private static void AddInfoBand(Section section, (string, string, string) cells)
        => AddInfoBand(section, new[] { cells.Item1, cells.Item2, cells.Item3 });

    private static void AddInfoBand(Section section, (string, string, string, string) cells)
        => AddInfoBand(section, new[] { cells.Item1, cells.Item2, cells.Item3, cells.Item4 });

    private static void AddSectionTitle(Section section, string text)
    {
        var p = section.AddParagraph(text);
        p.Format.Font.Bold = true;
        p.Format.Font.Size = 9;
        p.Format.SpaceBefore = Unit.FromPoint(6);
        p.Format.SpaceAfter = Unit.FromPoint(2);
    }

    private static void AddParentTable(Section section, RegistrationCardParentDTO? p)
    {
        var table = NewTable(section, 6);
        AddSpannedRow(table, ("Apellidos", 1, true), (JoinNames(p?.paternalLastName, p?.maternalLastName), 3, false),
                             ("Nombres", 1, true), (p?.firstName, 1, false));
        AddRow(table, ("DNI", true), (p?.dni, false),
                      ("Celular", true), (p?.phone, false),
                      ("Email", true), (p?.email, false));
        AddRow(table, ("Grado Instr.", true), (p?.educationLevel, false),
                      ("Ocupación", true), (p?.occupation, false),
                      ("Estado Civil", true), (p?.maritalStatus, false));
    }

    // Fees table (left half) and the documents checklist (right half) rendered side
    // by side in a single 6-column table, mirroring the original flex-row layout.
    // The left fee cells only span the top rows; the docs list fills all rows.
    private static void AddFeesAndDocs(Section section, RegistrationCardFeesDTO fees)
    {
        var table = section.AddTable();
        table.Borders.Width = 0; // borders are drawn per cell (fee block is shorter than docs)
        table.TopPadding = Unit.FromPoint(3);
        table.BottomPadding = Unit.FromPoint(3);
        table.LeftPadding = Unit.FromPoint(3);
        table.RightPadding = Unit.FromPoint(3);

        table.AddColumn(Unit.FromCentimeter(2.5)); // Tipo
        table.AddColumn(Unit.FromCentimeter(2.2)); // Monto
        table.AddColumn(Unit.FromCentimeter(2.2)); // Descuento
        table.AddColumn(Unit.FromCentimeter(2.1)); // Total
        table.AddColumn(Unit.FromCentimeter(7.5)); // Documento
        table.AddColumn(Unit.FromCentimeter(1.5)); // check box

        var feeRows = new (string Tipo, string Monto, string Descuento, string Total)[]
        {
            ("Tipo", "Monto", "Descuento", "Total"), // header
            Fee("Inscripción", fees.registrationFee, fees.registrationDiscount),
            Fee("Matrícula", fees.enrollmentFee, fees.enrollmentDiscount),
            Fee("Pensión", fees.tuition, fees.tuitionDiscount),
        };

        var rowCount = Math.Max(feeRows.Length, RequiredDocs.Length);
        for (var r = 0; r < rowCount; r++)
        {
            var row = table.AddRow();

            if (r < feeRows.Length)
            {
                var isHeader = r == 0;
                SetFeeCell(row.Cells[0], feeRows[r].Tipo, isHeader);
                SetFeeCell(row.Cells[1], feeRows[r].Monto, isHeader);
                SetFeeCell(row.Cells[2], feeRows[r].Descuento, isHeader);
                SetFeeCell(row.Cells[3], feeRows[r].Total, isHeader);
            }
            // rows past the fee block keep the left cells empty and border-less.

            if (r < RequiredDocs.Length)
            {
                Border(row.Cells[4]).AddParagraph(RequiredDocs[r]);
                Border(row.Cells[5]).AddParagraph(" ");
            }
        }
    }

    private static (string, string, string, string) Fee(string label, decimal amount, decimal discount)
        => (label, amount.ToString("0.00"), discount.ToString("0.00"), (amount - discount).ToString("0.00"));

    private static void SetFeeCell(Cell cell, string text, bool header)
    {
        Border(cell);
        if (header)
        {
            cell.Shading.Color = HeaderBg;
            cell.Format.Font.Bold = true;
        }
        cell.AddParagraph(text);
    }

    private static Cell Border(Cell cell)
    {
        cell.Borders.Width = BorderWidth;
        cell.Borders.Color = BorderColor;
        return cell;
    }

    private static void AddObservationBox(Section section)
    {
        section.AddParagraph().Format.SpaceBefore = Unit.FromPoint(8);
        var table = NewTable(section, 1);
        var row = table.AddRow();
        row.Height = Unit.FromCentimeter(1.6);
        row.Cells[0].AddParagraph("OBSERVACIÓN").Format.Font.Bold = true;
    }

    private static void AddSignatures(Section section)
    {
        var spacer = section.AddParagraph();
        spacer.Format.SpaceBefore = Unit.FromPoint(45);

        var table = section.AddTable();
        table.AddColumn(Unit.FromCentimeter(UsableWidthCm / 2));
        table.AddColumn(Unit.FromCentimeter(UsableWidthCm / 2));

        var row = table.AddRow();
        SignatureCell(row.Cells[0], new[] { "V°B°" });
        SignatureCell(row.Cells[1], new[] { "Firma del apoderado", "DNI:" });
    }

    private static void SignatureCell(Cell cell, string[] labels)
    {
        cell.Borders.Top.Width = BorderWidth;
        cell.Borders.Top.Color = new Color(0x44, 0x44, 0x44);
        foreach (var label in labels)
        {
            var p = cell.AddParagraph(label);
            p.Format.Alignment = ParagraphAlignment.Center;
        }
    }

    private static string JoinNames(string? a, string? b)
        => string.Join(" ", new[] { a, b }.Where(x => !string.IsNullOrWhiteSpace(x)));

    // Show DD/MM/YYYY, reading Y-M-D straight from the string to avoid timezone drift.
    private static string FormatDate(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return string.Empty;
        if (value.Length >= 10 &&
            DateOnly.TryParseExact(value[..10], "yyyy-MM-dd", out var iso))
            return iso.ToString("dd/MM/yyyy");
        return DateTime.TryParse(value, out var dt) ? dt.ToString("dd/MM/yyyy") : value;
    }
}
