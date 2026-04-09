using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetProvincesUseCase
{
    private readonly IProvinceRepository _provinceRepository;

    public GetProvincesUseCase(IProvinceRepository provinceRepository)
    {
        _provinceRepository = provinceRepository;
    }

    public async Task<List<ProvinceDTO>> ExecuteAsync(int? departmentId = null)
    {
        return await _provinceRepository.GetAllAsync(departmentId);
    }
}
