using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.Interfaces;

public interface ILunchAssignmentRepository
{
    Task<int> CreateAsync(DLunchAssignment assignment);
    Task<List<int>> CreateManyAsync(IEnumerable<DLunchAssignment> assignments);
    Task<DLunchAssignment?> GetByIdAsync(int id);
    Task<List<DLunchAssignment>> GetUnpaidByPersonAsync(int personId);
    Task UpdateDebtPaymentsAsync(IReadOnlyList<DLunchAssignment> assignments);
    Task<bool> DeleteAsync(int id);
    Task<bool> PersonExistsAsync(int personId);
    Task<bool> EnrollmentBelongsToPersonAsync(int enrollmentId, int personId);
    Task<bool> ShiftExistsAsync(int shiftId);
}
