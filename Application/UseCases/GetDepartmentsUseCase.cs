using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetDepartmentsUseCase
{
    private readonly IDepartmentRepository _departmentRepository;

    public GetDepartmentsUseCase(IDepartmentRepository departmentRepository)
    {
        _departmentRepository = departmentRepository;
    }

    public async Task<List<DepartmentDTO>> ExecuteAsync(string? name = null)
    {
        return await _departmentRepository.GetAllAsync(name);
    }
}
