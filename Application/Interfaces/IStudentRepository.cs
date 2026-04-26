using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.Interfaces;

public interface IStudentRepository
{
    Task<(List<DStudent> Items, int Total)> GetPagedAsync(int skip, int take);
    Task<DStudent?> GetByIdAsync(int id);
    Task<bool> ExistsByEducationalPersonIdAsync(int educationalPersonId);
    Task CreateAsync(DStudent student, int personId);
    Task CreateHomeAsync(DStudent student, int studentId);
    Task UpdateAsync(DStudent student);
    Task UpdateHomeAsync(DStudent student);
    Task<bool> ExistsAsync(int id);
    Task<bool> TryDeleteAsync(int id);
}
