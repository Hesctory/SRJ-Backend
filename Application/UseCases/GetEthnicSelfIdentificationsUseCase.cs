using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetEthnicSelfIdentificationsUseCase
{
    private readonly IEthnicSelfIdentificationRepository _ethnicSelfIdentificationRepository;

    public GetEthnicSelfIdentificationsUseCase(IEthnicSelfIdentificationRepository ethnicSelfIdentificationRepository)
    {
        _ethnicSelfIdentificationRepository = ethnicSelfIdentificationRepository;
    }

    public async Task<List<EthnicSelfIdentificationDTO>> ExecuteAsync()
    {
        return await _ethnicSelfIdentificationRepository.GetAllAsync();
    }
}
