using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Reports;

/// <summary>
/// Orchestrates report exports: fetches the data through <see cref="IStudentQueries"/>,
/// applies the report-specific formatting, and delegates to the PDF/Excel renderers.
/// Returns <c>null</c> when no rows match so the controller can emit 204.
/// </summary>
public sealed class StudentReportExporter : IStudentReportExporter
{
    private const string PdfContentType = "application/pdf";
    private const string XlsxContentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

    private static readonly string[] MonthsEs =
    {
        "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
        "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
    };

    private readonly IStudentQueries _queries;
    private readonly IClock _clock;
    private readonly TablePdfRenderer _tablePdf;
    private readonly TableExcelRenderer _tableExcel;
    private readonly RegistrationCardPdfRenderer _cardPdf;
    private readonly RegistrationCardExcelRenderer _cardExcel;

    public StudentReportExporter(
        IStudentQueries queries,
        IClock clock,
        TablePdfRenderer tablePdf,
        TableExcelRenderer tableExcel,
        RegistrationCardPdfRenderer cardPdf,
        RegistrationCardExcelRenderer cardExcel)
    {
        _queries = queries;
        _clock = clock;
        _tablePdf = tablePdf;
        _tableExcel = tableExcel;
        _cardPdf = cardPdf;
        _cardExcel = cardExcel;
    }

    public async Task<ReportFile?> ExportEnrolledAsync(
        int? schoolYearId, int? levelId, int? gradeId, int? shiftId, int? sectionId, ReportFormat format)
    {
        var items = await _queries.GetReportAsync(schoolYearId, levelId, gradeId, shiftId, sectionId);
        if (items.Count == 0) return null;

        var contextLine = await BuildContextLineAsync(schoolYearId, levelId, gradeId, shiftId, sectionId);
        var model = new TableReportModel
        {
            Title = "Reporte de Estudiantes Matriculados",
            ContextLine = contextLine,
            Columns = new[]
            {
                new TableColumn("#", 0.8, Numeric: true),
                new TableColumn("Código", 2.8),
                new TableColumn("DNI", 2.1),
                new TableColumn("Apellidos y Nombres", 6.2),
                new TableColumn("Académico", 3.8),
                new TableColumn("Turno", 2.3),
            },
            Rows = items.Select((s, i) => (IReadOnlyList<string>)new[]
            {
                (i + 1).ToString(),
                s.EnrollmentCode,
                s.DocumentNumber,
                s.FullName,
                FormatAcademic(s.GradeYear.ToString(), s.Section?.ToString(), s.Level),
                s.Shift,
            }).ToList()
        };

        return BuildTableFile(model, "Estudiantes-Matriculados", format);
    }

    public async Task<ReportFile?> ExportBirthdaysAsync(
        int? schoolYearId, int? levelId, int? gradeId, int? shiftId, int? sectionId, ReportFormat format)
    {
        var items = await _queries.GetBirthdaysAsync(schoolYearId, levelId, gradeId, shiftId, sectionId);
        if (items.Count == 0) return null;

        var contextLine = await BuildContextLineAsync(schoolYearId, levelId, gradeId, shiftId, sectionId);
        var model = new TableReportModel
        {
            Title = "Reporte de Cumpleaños",
            ContextLine = contextLine,
            Columns = new[]
            {
                new TableColumn("#", 0.9, Numeric: true),
                new TableColumn("DNI", 2.2),
                new TableColumn("Apellidos y Nombres", 7.0),
                new TableColumn("Académico", 4.0),
                new TableColumn("Cumpleaños", 3.9),
            },
            Rows = items.Select((s, i) => (IReadOnlyList<string>)new[]
            {
                (i + 1).ToString(),
                s.DocumentNumber,
                s.FullName,
                FormatAcademic(s.GradeYear, s.Section, s.Level),
                FormatBirthday(s.BirthDate),
            }).ToList()
        };

        return BuildTableFile(model, "Cumpleanos-Estudiantes", format);
    }

    public async Task<ReportFile?> ExportWithdrawnAsync(
        int? schoolYearId, int? levelId, int? gradeId, int? shiftId, int? sectionId, ReportFormat format)
    {
        var items = await _queries.GetWithdrawnAsync(schoolYearId, levelId, gradeId, shiftId, sectionId);
        if (items.Count == 0) return null;

        var contextLine = await BuildContextLineAsync(schoolYearId, levelId, gradeId, shiftId, sectionId);
        var model = new TableReportModel
        {
            Title = "Reporte de Estudiantes Retirados",
            ContextLine = contextLine,
            Columns = new[]
            {
                new TableColumn("#", 0.8, Numeric: true),
                new TableColumn("Código", 2.8),
                new TableColumn("Apellidos y Nombres", 5.4),
                new TableColumn("Académico", 4.0),
                new TableColumn("F. Matrícula", 2.5),
                new TableColumn("F. Retiro", 2.5),
            },
            Rows = items.Select((s, i) => (IReadOnlyList<string>)new[]
            {
                (i + 1).ToString(),
                s.EnrollmentCode,
                s.FullName,
                FormatAcademic(s.GradeYear, s.Section, s.Level),
                FormatDate(s.EnrollmentDate),
                FormatDate(s.WithdrawalDate),
            }).ToList()
        };

        return BuildTableFile(model, "Estudiantes-Retirados", format);
    }

    public async Task<ReportFile?> ExportRegistrationCardAsync(
        int? schoolYearId, int? levelId, int? gradeId, int? shiftId, int? sectionId,
        List<int>? studentIds, ReportFormat format)
    {
        var items = await _queries.GetRegistrationCardAsync(
            schoolYearId, levelId, gradeId, shiftId, sectionId, studentIds);
        if (items.Count == 0) return null;

        if (format == ReportFormat.Pdf)
        {
            // Peru has a fixed UTC-5 offset (no DST) — render the generated timestamp in local time.
            var generatedAt = _clock.UtcNow.AddHours(-5);
            var bytes = _cardPdf.Render(items, generatedAt);
            return new ReportFile(bytes, PdfContentType, "Ficha-Matricula.pdf");
        }

        var xlsx = _cardExcel.Render(items);
        return new ReportFile(xlsx, XlsxContentType, "Ficha-Matricula.xlsx");
    }

    private ReportFile BuildTableFile(TableReportModel model, string baseName, ReportFormat format)
    {
        if (format == ReportFormat.Pdf)
            return new ReportFile(_tablePdf.Render(model), PdfContentType, $"{baseName}.pdf");

        var bytes = _tableExcel.Render(model, baseName);
        return new ReportFile(bytes, XlsxContentType, $"{baseName}.xlsx");
    }

    private async Task<string> BuildContextLineAsync(
        int? schoolYearId, int? levelId, int? gradeId, int? shiftId, int? sectionId)
    {
        var ctx = await _queries.GetReportContextAsync(schoolYearId, levelId, gradeId, shiftId, sectionId);
        var parts = new List<string>();
        if (!string.IsNullOrWhiteSpace(ctx.SchoolYear)) parts.Add($"Año: {ctx.SchoolYear}");
        if (!string.IsNullOrWhiteSpace(ctx.Level)) parts.Add($"Nivel: {ctx.Level}");
        if (!string.IsNullOrWhiteSpace(ctx.Grade)) parts.Add($"Grado: {ctx.Grade}");
        if (!string.IsNullOrWhiteSpace(ctx.Shift)) parts.Add($"Turno: {ctx.Shift}");
        if (!string.IsNullOrWhiteSpace(ctx.Section)) parts.Add($"Sección: {ctx.Section}");
        return parts.Count > 0 ? string.Join("  ·  ", parts) : "Todos los estudiantes";
    }

    // Compact "N° Section, Level" academic label shared by all tabular reports.
    private static string FormatAcademic(string? gradeYear, string? section, string? level)
        => $"{gradeYear}° {section}, {level}";

    // "yyyy-MM-dd" → "D de Mes" in Spanish, read straight from the string parts.
    private static string FormatBirthday(string? value)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length < 10) return "—";
        if (int.TryParse(value.Substring(5, 2), out var month) &&
            int.TryParse(value.Substring(8, 2), out var day) &&
            month is >= 1 and <= 12)
            return $"{day} de {MonthsEs[month - 1]}";
        return "—";
    }

    // "yyyy-MM-dd" → "DD/MM/YYYY", read straight from the string parts (no TZ drift).
    private static string FormatDate(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return "—";
        if (value.Length >= 10 &&
            DateOnly.TryParseExact(value[..10], "yyyy-MM-dd", out var iso))
            return iso.ToString("dd/MM/yyyy");
        return DateTime.TryParse(value, out var dt) ? dt.ToString("dd/MM/yyyy") : "—";
    }
}
