using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Queries;

public class LocationQueries : ILocationQueries
{
    private readonly IDepartmentRepository _departmentRepo;
    private readonly IProvinceRepository _provinceRepo;
    private readonly IDistrictRepository _districtRepo;

    public LocationQueries(IDepartmentRepository departmentRepo, IProvinceRepository provinceRepo, IDistrictRepository districtRepo)
    {
        _departmentRepo = departmentRepo;
        _provinceRepo = provinceRepo;
        _districtRepo = districtRepo;
    }

    public Task<List<DepartmentDTO>> GetDepartmentsAsync(string? name = null) => _departmentRepo.GetAllAsync(name);
    public Task<List<ProvinceDTO>> GetProvincesAsync(int? departmentId = null) => _provinceRepo.GetAllAsync(departmentId);
    public Task<List<DistrictDTO>> GetDistrictsAsync(int? provinceId = null) => _districtRepo.GetAllAsync(provinceId);
}
