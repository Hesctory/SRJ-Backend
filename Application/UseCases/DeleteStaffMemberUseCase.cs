using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class DeleteStaffMemberUseCase
{
    private readonly IStaffMemberRepository _staffMemberRepository;
    private readonly IPersonRepository _personRepository;

    public DeleteStaffMemberUseCase(
        IStaffMemberRepository staffMemberRepository,
        IPersonRepository personRepository)
    {
        _staffMemberRepository = staffMemberRepository;
        _personRepository = personRepository;
    }

    public async Task<bool> ExecuteAsync(int id)
    {
        if (!await _staffMemberRepository.ExistsAsync(id))
            return false;

        var deleted = await _staffMemberRepository.TryDeleteAsync(id);
        if (deleted)
            await _personRepository.TryDeleteAsync(id);

        return deleted;
    }
}
