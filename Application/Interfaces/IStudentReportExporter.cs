using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

/// <summary>
/// Generates downloadable report files (PDF / Excel) for the student reports.
/// Each method fetches the underlying data, applies the report's formatting, and
/// renders it. Returns <c>null</c> when no rows match the filters, so the caller
/// can respond with <c>204 No Content</c> instead of a blank file.
/// </summary>
public interface IStudentReportExporter
{
    Task<ReportFile?> ExportEnrolledAsync(
        int? schoolYearId, int? levelId, int? gradeId, int? shiftId, int? sectionId, ReportFormat format);

    Task<ReportFile?> ExportBirthdaysAsync(
        int? schoolYearId, int? levelId, int? gradeId, int? shiftId, int? sectionId, ReportFormat format);

    Task<ReportFile?> ExportWithdrawnAsync(
        int? schoolYearId, int? levelId, int? gradeId, int? shiftId, int? sectionId, ReportFormat format);

    Task<ReportFile?> ExportRegistrationCardAsync(
        int? schoolYearId, int? levelId, int? gradeId, int? shiftId, int? sectionId,
        List<int>? studentIds, ReportFormat format);
}
