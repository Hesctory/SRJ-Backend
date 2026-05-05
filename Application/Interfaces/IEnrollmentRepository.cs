using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.Interfaces;

public interface IEnrollmentRepository
{
    Task<int> CreateAsync(DEnrollment enrollment);
    Task<bool> ExistsForStudentInYearAsync(int studentId, int schoolYearId);
    Task<int?> GetSchoolYearIdForSectionAsync(int sectionId);
    Task<int> NextCodeNumberForYearAsync(int schoolYearId);
}