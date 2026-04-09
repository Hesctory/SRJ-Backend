using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IDistrictRepository
{
    Task<List<DistrictDTO>> GetAllAsync(int? provinceId = null);
}
