using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.Interfaces;

public interface IStudentRepository
{
    Task<List<DStudent>> GetAllAsync();
    Task<DStudent?> GetByIdAsync(int id);
}
