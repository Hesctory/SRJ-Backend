using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IStudentQueries
{
    Task<(List<StudentListDTO> Items, int Total)> GetPagedAsync(int skip, int take, StudentFilter? filter = null);
    Task<StudentDetailDTO?> GetByIdAsync(int id);
    Task<List<StudentReportItemDTO>> GetReportAsync(int? schoolYearId, int? levelId, int? gradeId, int? shiftId, int? sectionId);
    Task<List<StudentBirthdayDTO>> GetBirthdaysAsync(int? schoolYearId, int? levelId, int? gradeId, int? shiftId, int? sectionId);
    Task<List<WithdrawnStudentDTO>> GetWithdrawnAsync(int? schoolYearId, int? levelId, int? gradeId, int? shiftId, int? sectionId);
    Task<List<RegistrationCardDTO>> GetRegistrationCardAsync(
        int? schoolYearId, int? levelId, int? gradeId, int? shiftId, int? sectionId,
        List<int>? studentIds);
    Task<ReportContextDTO> GetReportContextAsync(
        int? schoolYearId, int? levelId, int? gradeId, int? shiftId, int? sectionId);
}
