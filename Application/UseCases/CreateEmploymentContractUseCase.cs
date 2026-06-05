using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.Mappers;

namespace SRJBackend.Application.UseCases;

public class CreateEmploymentContractUseCase
{
    private readonly IStaffMemberRepository _staffMemberRepository;
    private readonly IEmploymentContractRepository _contractRepository;

    public CreateEmploymentContractUseCase(
        IStaffMemberRepository staffMemberRepository,
        IEmploymentContractRepository contractRepository)
    {
        _staffMemberRepository = staffMemberRepository;
        _contractRepository = contractRepository;
    }

    public async Task<int> ExecuteAsync(CreateEmploymentContractDTO dto)
    {
        if (!await _staffMemberRepository.ExistsAsync(dto.StaffMemberId))
            throw new KeyNotFoundException("El personal indicado no existe.");

        var contract = StaffMemberMapper.ContractFromDTO(dto);
        return await _contractRepository.CreateAsync(contract);
    }
}
