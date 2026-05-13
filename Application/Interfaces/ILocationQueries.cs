using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface ILocationQueries
{
    Task<List<DepartmentDTO>> GetDepartmentsAsync(string? name = null);
    Task<List<ProvinceDTO>> GetProvincesAsync(int? departmentId = null);
    Task<List<DistrictDTO>> GetDistrictsAsync(int? provinceId = null);
}
