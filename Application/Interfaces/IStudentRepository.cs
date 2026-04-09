using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.Interfaces;

public interface IStudentRepository
{
    Task<(List<DStudent> Items, int Total)> GetPagedAsync(int skip, int take);
    Task<DStudent?> GetByIdAsync(int id);
}
