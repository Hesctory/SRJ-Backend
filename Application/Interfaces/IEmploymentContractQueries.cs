using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IEmploymentContractQueries
{
    Task<(List<EmploymentContractDTO> Items, int Total)> GetPagedAsync(int skip, int take, EmploymentContractFilter? filter = null);
    Task<EmploymentContractDTO?> GetByIdAsync(int id);
}
