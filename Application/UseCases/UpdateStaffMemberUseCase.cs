using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.Mappers;

namespace SRJBackend.Application.UseCases;

public class UpdateStaffMemberUseCase
{
    private readonly IPersonRepository _personRepository;
    private readonly IStaffMemberRepository _staffMemberRepository;

    public UpdateStaffMemberUseCase(
        IPersonRepository personRepository,
        IStaffMemberRepository staffMemberRepository)
    {
        _personRepository = personRepository;
        _staffMemberRepository = staffMemberRepository;
    }

    public async Task ExecuteAsync(int id, UpdateStaffMemberDTO dto)
    {
        if (!await _staffMemberRepository.ExistsAsync(id))
            throw new KeyNotFoundException("El personal indicado no existe.");

        var staffMember = StaffMemberMapper.FromDTO(dto, id);
        await _personRepository.UpdateAsync(id, staffMember);
        await _staffMemberRepository.UpdateAsync(staffMember);
    }
}
