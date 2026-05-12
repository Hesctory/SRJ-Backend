using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.Interfaces;

public interface IEnrollmentRepository
{
    Task<int?> FindSectionIdAsync(int schoolYearId, int gradeId, int shiftId, int sectionId);
    Task<DEnrollment> CreateAsync(int studentId, int sectionId, int schoolFeeConceptId, int schoolYearId, string? previousSchool = null);
    Task<List<DEnrollment>> GetByStudentIdAsync(int studentId);
    Task<DEnrollment?> GetLatestByStudentIdAsync(int studentId);
    Task<DEnrollment?> GetByStudentIdAndYearAsync(int studentId, int schoolYearId);
}
