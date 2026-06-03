using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IEnrollmentDebtQueries
{
    Task<(List<EnrollmentDebtDTO> Items, int Total)> GetByEnrollmentAsync(int enrollmentId, int skip, int take);
    Task<EnrollmentDebtDTO?> GetByIdAsync(long id);
}
