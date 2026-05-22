using SRJBackend.Domain.Entities;
using SRJBackend.Domain.ValueObjects;

namespace SRJBackend.Application.Interfaces;

public interface IEnrollmentRepository
{
    Task<DEnrollment> CreateAsync(int studentId, AcademicPlacement placement, int schoolFeeConceptId, int schoolYearId, string? previousSchool = null, bool isNew = false);
    Task<DEnrollment?> GetByIdAsync(int id);
    Task<List<DEnrollment>> GetByStudentIdAsync(int studentId);
    Task<DEnrollment?> GetLatestByStudentIdAsync(int studentId);
    Task<DEnrollment?> GetByStudentIdAndYearAsync(int studentId, int schoolYearId);
    Task<DEnrollment> UpdateAsync(int id, AcademicPlacement placement, int schoolFeeConceptId, string? previousSchool);
    Task<bool> DeleteAsync(int id);
    Task<bool> CancelAsync(int id);
    Task<bool> WithdrawAsync(int id);
    Task<bool> ReactivateAsync(int id);
}
