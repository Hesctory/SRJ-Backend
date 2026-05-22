using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IEnrollmentQueries
{
    Task<List<EnrollmentSummaryDTO>> GetByStudentAsync(int studentId);
    Task<EnrollmentDTO?> GetByIdAsync(int id);
    Task<EnrollmentDTO?> GetLatestByStudentAsync(int studentId);
    Task<bool> HasValidEnrollmentsAsync(int studentId);
}
