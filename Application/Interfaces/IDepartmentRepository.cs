using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IDepartmentRepository
{
    Task<List<DepartmentDTO>> GetAllAsync(string? name = null);
}
