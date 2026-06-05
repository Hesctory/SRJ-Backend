using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.Mappers;

namespace SRJBackend.Application.UseCases;

public class CreateStaffMemberUseCase
{
    private readonly IPersonRepository _personRepository;
    private readonly IStaffMemberRepository _staffMemberRepository;
    private readonly IEmploymentContractRepository _contractRepository;
    private readonly IUnitOfWork _unitOfWork;

    public CreateStaffMemberUseCase(
        IPersonRepository personRepository,
        IStaffMemberRepository staffMemberRepository,
        IEmploymentContractRepository contractRepository,
        IUnitOfWork unitOfWork)
    {
        _personRepository = personRepository;
        _staffMemberRepository = staffMemberRepository;
        _contractRepository = contractRepository;
        _unitOfWork = unitOfWork;
    }

    public async Task<int> ExecuteAsync(CreateStaffMemberDTO dto)
    {
        var existingPersonId = await _personRepository.FindByDocumentAsync(dto.DocumentTypeId, dto.IdDocumentNumber);

        if (existingPersonId != null && await _staffMemberRepository.IsStaffMemberAsync(existingPersonId.Value))
            throw new InvalidOperationException("Esta persona ya está registrada como personal.");

        var staffMember = StaffMemberMapper.FromDTO(dto);

        await _unitOfWork.BeginAsync();
        try
        {
            var personId = existingPersonId ?? await _personRepository.CreateAsync(staffMember);

            await _staffMemberRepository.CreateAsync(staffMember, personId);

            var contract = StaffMemberMapper.ContractFromDetails(dto.Contract, personId);
            await _contractRepository.CreateAsync(contract);

            await _unitOfWork.CommitAsync();
            return personId;
        }
        catch
        {
            await _unitOfWork.RollbackAsync();
            throw;
        }
    }
}
