using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetDistrictsUseCase
{
    private readonly IDistrictRepository _districtRepository;

    public GetDistrictsUseCase(IDistrictRepository districtRepository)
    {
        _districtRepository = districtRepository;
    }

    public async Task<List<DistrictDTO>> ExecuteAsync(int? provinceId = null)
    {
        return await _districtRepository.GetAllAsync(provinceId);
    }
}
