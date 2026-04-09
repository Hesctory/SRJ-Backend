using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IEthnicSelfIdentificationRepository
{
    Task<List<EthnicSelfIdentificationDTO>> GetAllAsync();
}
