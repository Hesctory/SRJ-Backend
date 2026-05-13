using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IEnrollmentQueries
{
    Task<List<EnrollmentDTO>> GetByStudentAsync(int studentId);
    Task<EnrollmentDTO?> GetLatestByStudentAsync(int studentId);
}
