using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Application.Interfaces;

public interface IStudentHomeRepository
{
    Task<StudentHome?> GetByStudentIdAsync(int studentId);
    Task CreateAsync(StudentHome studentHome);
    Task<bool> ExistsAsync(int studentId);
    Task DeleteAsync(int studentId);
}
