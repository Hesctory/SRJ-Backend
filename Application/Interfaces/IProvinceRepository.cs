using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IProvinceRepository
{
    Task<List<ProvinceDTO>> GetAllAsync(int? departmentId = null);
}
